using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using System.IO;
using System.Drawing;

namespace analyze
{
    class Program
    {
        static string texConvCVTTPath = "Texconv\\bin\\Desktop_2017\\x64\\Release\\texconv.exe";
        static string texConvStockPath = "Tests\\Stock\\texconv.exe";
        static string texConvRGPath = "Tests\\Stock\\texconv-rg.exe";

        enum CompressedFormat
        {
            BC7,
            BC6H,
        }

        struct BenchmarkResult
        {
            public double error;
            public double worstBlock;
            public int worstBlockX;
            public int worstBlockY;

            public BenchmarkResult(double error, double worstBlock, int worstBlockX, int worstBlockY)
            {
                this.error = error;
                this.worstBlock = worstBlock;
                this.worstBlockX = worstBlockX;
                this.worstBlockY = worstBlockY;
            }
        }

        struct ImageDimensions : IEquatable<ImageDimensions>
        {
            public int width;
            public int height;

            public ImageDimensions(int width, int height)
            {
                this.width = width;
                this.height = height;
            }

            public override int GetHashCode()
            {
                return width.GetHashCode() * 3 + height.GetHashCode();
            }

            public override bool Equals(object o)
            {
                if (o != null && o.GetType() == typeof(ImageDimensions))
                    return this.Equals((ImageDimensions)o);
                return false;
            }

            public bool Equals(ImageDimensions other)
            {
                return this.width == other.width && this.height == other.height;
            }
        }

        static void MakeAlphaImage(string rgbPath, string alphaPath, string outPath)
        {
            using (Bitmap rgb = (Bitmap)Bitmap.FromFile(rgbPath))
            {
                using (Bitmap alpha = (Bitmap)Bitmap.FromFile(alphaPath))
                {
                    int w = rgb.Width;
                    int h = rgb.Height;

                    using (Bitmap mixed = new Bitmap(rgb.Width, rgb.Height, System.Drawing.Imaging.PixelFormat.Format32bppArgb))
                    {
                        for (int y = 0; y < h; y++)
                        {
                            for (int x = 0; x < w; x++)
                            {
                                Color rgbPx = rgb.GetPixel(x, y);
                                Color aPx = alpha.GetPixel(x, y);

                                int finalAlpha = (aPx.R + aPx.G + aPx.B) / 3;
                                mixed.SetPixel(x, y, Color.FromArgb(finalAlpha, rgbPx.R, rgbPx.G, rgbPx.B));
                            }
                        }

                        mixed.Save(outPath, System.Drawing.Imaging.ImageFormat.Png);
                    }
                }
            }
        }

        static Color AlphaWeight(Color c)
        {
            int a = c.A;
            int r = c.R * a / 255;
            int g = c.G * a / 255;
            int b = c.B * a / 255;

            return Color.FromArgb(a, r, g, b);
        }

        static ushort[] LoadHDR(string path, out int width, out int height)
        {
            using (FileStream fs = new FileStream(path, FileMode.Open, FileAccess.Read))
            {
                DDSFile.DDSHeader header = DDSFile.DDSParser.ReadDDSHeader(fs);

                ushort[] shorts = new ushort[header.width * header.height * 4];
                byte[] bytes = new byte[shorts.Length * 2];

                fs.Read(bytes, 0, bytes.Length);

                for (int i = 0; i < bytes.Length; i += 2)
                {
                    int px = (bytes[i]) | (bytes[i + 1] << 8);
                    shorts[i / 2] = (ushort)px;
                }

                width = (int)header.width;
                height = (int)header.height;

                return shorts;
            }
        }

        static double UnpackFP16(ushort v)
        {
            bool isNegative = ((v & 0x8000) != 0);
            int exponent = ((v & 0x7c00) >> 10);
            int fraction = (v & 0x03ff);

            double ffraction = ((double)fraction) * (1.0 / 1024.0);
            double f;

            if (exponent == 0)
            {
                if (fraction == 0)
                    return isNegative ? -0.0 : 0.0;

                f = ffraction * (1.0 / 16384.0);
            }
            else if (exponent == 0x1f)
            {
                if (fraction == 0)
                    return isNegative ? float.NegativeInfinity : float.PositiveInfinity;
            
                return float.NaN;
            }
            else
                f = (float)(1 << exponent) * (1.0 / 32768.0) * (1.0 + ffraction);

            return isNegative ? -f : f;
        }

        static double PerceptualCurve(double f)
        {
            bool isNegative = (f < 0.0f);

            if (isNegative)
                f = -f;

            f = Math.Pow(f, 1.0f / 2.2f);

            if (isNegative)
                f = -f;

            return f;
        }

        static double F16Error(ushort a, ushort b)
        {
            if (true)
            {
                if (a > b)
                    return a - b;
                else
                    return b - a;
            }
            else
            {
                double af = PerceptualCurve(UnpackFP16(a));
                double bf = PerceptualCurve(UnpackFP16(b));

                double diff = af - bf;
                return diff * diff;
            }
        }

        static BenchmarkResult BenchmarkHDR(string compressedPath, string originalPath, int uid)
        {
            RunProcess(texConvCVTTPath, "-m 1 -f FP16 -px decode_ -y " + compressedPath);

            int lastBackslash = compressedPath.LastIndexOf('\\');
            string tempPath = "decode_" + compressedPath.Substring(lastBackslash + 1);

            int width;
            int height;
            ushort[] compressedPixels = LoadHDR(tempPath, out width, out height);
            ushort[] originalPixels = LoadHDR(originalPath, out width, out height);

            double worstError = 0.0;
            int worstX = 0;
            int worstY = 0;

            double error = 0.0;

            for (int baseY = 0; baseY < height; baseY += 4)
            {
                for (int baseX = 0; baseX < width; baseX += 4)
                {
                    double blockError = 0.0;
                    for (int subY = 0; subY < 4; subY++)
                    {
                        for (int subX = 0; subX < 4; subX++)
                        {
                            int x = baseX + subX;
                            int y = baseY + subY;
                            int pxStart = ((y * width) + x) * 4;

                            for (int ch = 0; ch < 4; ch++)
                                blockError += F16Error(compressedPixels[pxStart + ch], originalPixels[pxStart + ch]);
                        }
                    }

                    if (blockError > worstError)
                    {
                        worstError = blockError;
                        worstX = baseX;
                        worstY = baseY;
                    }

                    error += blockError;
                }
            }

            BenchmarkResult result = new BenchmarkResult(error, worstError, worstX, worstY);

            File.Delete(tempPath);

            return result;
        }

        static BenchmarkResult BenchmarkLDR(string compressedPath, string originalPath, int uid)
        {
            string compressonatorPath = "C:\\Program Files\\Compressonator\\CompressonatorCLI.exe";

            string tempPath = "temp" + uid.ToString() + ".png";

            RunProcess(compressonatorPath, compressedPath + " " + tempPath);

            BenchmarkResult result;

            using (Bitmap decompressed = (Bitmap)Bitmap.FromFile(tempPath))
            {
                using (Bitmap original = (Bitmap)Bitmap.FromFile(originalPath))
                {
                    int w = decompressed.Width;
                    int h = decompressed.Height;

                    double worstBlock = 0.0;
                    double totalError = 0.0;
                    int worstBlockX = 0;
                    int worstBlockY = 0;

                    int blockSize = 4;

                    for (int y = 0; y < h; y += 4)
                    {
                        for (int x = 0; x < w; x += 4)
                        {
                            double blockError = 0.0;
                            for (int subY = y; subY < y + blockSize && subY < h; subY++)
                            {
                                for (int subX = x; subX < x + blockSize && subX < w; subX++)
                                {
                                    Color px1 = AlphaWeight(decompressed.GetPixel(subX, subY));
                                    Color px2 = AlphaWeight(original.GetPixel(subX, subY));

                                    int rDiff = px1.R - px2.R;
                                    int gDiff = px1.G - px2.G;
                                    int bDiff = px1.B - px2.B;
                                    int aDiff = px1.A - px2.A;


                                    blockError += rDiff * rDiff + gDiff * gDiff + bDiff * bDiff + aDiff * aDiff;
                                }
                            }

                            totalError += blockError;

                            if (blockError > worstBlock)
                            {
                                worstBlock = blockError;
                                worstBlockX = x;
                                worstBlockY = y;
                            }
                        }
                    }

                    result = new BenchmarkResult(totalError, worstBlock, worstBlockX, worstBlockY);
                }
            }

            System.IO.File.Delete(tempPath);

            return result;
        }

        static void RunProcess(string path, string args)
        {
            System.Console.WriteLine("Running " + path + " " + args);
            using (System.Diagnostics.Process p = System.Diagnostics.Process.Start(path, args))
                p.WaitForExit();
        }

        static string ReplaceExtension(string path, string suffix)
        {
            int lastPeriod = path.LastIndexOf('.');
            return path.Substring(0, lastPeriod) + suffix;
        }

        static string CompressWithCompressonator(CompressedFormat targetFormat, string path, bool hq, bool run)
        {
            string compressonatorPath = "C:\\Program Files\\Compressonator\\CompressonatorCLI.exe";

            string resultPath = ReplaceExtension(path, hq ? "_chq.dds" : "_c.dds");

            if (run)
            {
                string args = "-nomipmap ";

                if (targetFormat == CompressedFormat.BC7)
                    args += "-fd BC7 ";
                else if (targetFormat == CompressedFormat.BC6H)
                    args += "-fd BC6H ";

                if (hq)
                    args += "-Quality 1.0 ";

                RunProcess(compressonatorPath, args + path + " " + resultPath);
            }

            return resultPath;
        }

        static string CompressWithNVTT(CompressedFormat targetFormat, string path, bool run)
        {
            string nvttPath = "tests\\nvtt\\nvcompress.exe";

            string resultPath = ReplaceExtension(path, "_nvtt.dds");

            if (run)
            {
                string args = "-nomips -alpha ";
                if (targetFormat == CompressedFormat.BC7)
                    args += "-bc7 ";
                else if (targetFormat == CompressedFormat.BC6H)
                    args += "-bc6 ";

                RunProcess(nvttPath, args + path + " " + resultPath);
            }

            return resultPath;
        }

        static string CompressWithDirectXTex(CompressedFormat targetFormat, string path, string exePath, string suffix, bool useGPU, bool useHQ, bool run)
        {
            string resultPath = ReplaceExtension(path, "");

            resultPath += suffix + ".dds";

            if (run)
            {
                string args = "-m 1 -y -bcmax -bcuniform ";

                if (targetFormat == CompressedFormat.BC7)
                    args += "-srgbi -srgbo -f BC7_UNORM ";
                else if (targetFormat == CompressedFormat.BC6H)
                    args += "-f BC6H_UF16 ";

                if (!useGPU)
                    args += "-nogpu ";
                if (useHQ)
                    args += "-bchq ";
                args += path;

                RunProcess(exePath, args);

                int lastSlash = path.LastIndexOf('\\');
                string outputPath = path.Substring(lastSlash + 1).Replace(".png", ".DDS");

                if (System.IO.File.Exists(resultPath))
                    System.IO.File.Delete(resultPath);

                System.IO.File.Move(outputPath, resultPath);
            }

            return resultPath;
        }

        static string CompressWithFasTC(string path, bool run)
        {
            string fastcPath = "x64\\Release\\FasTCTest.exe";

            string resultPath = ReplaceExtension(path, "_fastc.dds");

            if (run)
                RunProcess(fastcPath, path + " " + resultPath);

            return resultPath;
        }

        static string CompressWithISPC(string path, bool run)
        {
            string fastcPath = "x64\\Release\\ISPCTextureCompressor.exe";

            string resultPath = ReplaceExtension(path, "_ispc.dds");

            if (run)
                RunProcess(fastcPath, path + " " + resultPath);

            return resultPath;
        }

        delegate BenchmarkResult BenchmarkDelegate(string compressedPath, string originalPath, int uid);

        static void Main(string[] args)
        {
            bool runCompressonator = false;
            bool runNVTT = false;
            bool runDXCPU = true;
            bool runDXCPU_Stock = false;
            bool runDX = false;
            bool runDXHQ = false;
            bool runFasTC = false;
            bool runISPC = false;
            bool runConversions = false;

            string[] testImages = {
                "kodim01.png", "kodim02.png", "kodim03.png", "kodim04.png", "kodim05.png", "kodim06.png",
                "kodim07.png", "kodim08.png", "kodim09.png", "kodim10.png", "kodim11.png", "kodim12.png",
                "kodim13.png", "kodim14.png", "kodim15.png", "kodim16.png", "kodim17.png", "kodim18.png",
                "kodim19.png", "kodim20.png", "kodim21.png", "kodim22.png", "kodim23.png", "kodim24.png"
                //"mossy_forest_1k.dds",
                //"pillars_1k.dds",
                //"simons_town_rocks_1k.dds",
                //"tears_of_steel_bridge_1k.dds",
            };

            string testDir = "tests\\";

            CompressedFormat targetFormat = CompressedFormat.BC7;
            BenchmarkDelegate benchmarkFunc = BenchmarkLDR;
            bool testAlpha = true;
            
            Dictionary<ImageDimensions, List<string>> imagesBySize = new Dictionary<ImageDimensions, List<string>>();

            List<string> testImagesFinal = new List<string>();

            foreach (string path in testImages)
            {
                if (testAlpha)
                {
                    using (Bitmap img = (Bitmap)Bitmap.FromFile(testDir + path))
                    {
                        ImageDimensions dim = new ImageDimensions(img.Width, img.Height);

                        List<string> paths;
                        if (!imagesBySize.TryGetValue(dim, out paths))
                        {
                            paths = new List<string>();
                            imagesBySize.Add(dim, paths);
                        }
                        paths.Add(path);
                    }
                }

                testImagesFinal.Add(testDir + path);
            }

            if (testAlpha)
            {
                foreach (KeyValuePair<ImageDimensions, List<string>> pair in imagesBySize)
                {
                    List<string> paths = pair.Value;

                    Parallel.For(0, paths.Count, i =>
                    {
                        string rgbImage = paths[i];
                        string alphaImage = paths[(i + 1) % paths.Count];
                        string blendImage = rgbImage.Replace(".png", "_alpha.png");

                        if (runConversions)
                            MakeAlphaImage(testDir + rgbImage, testDir + alphaImage, testDir + blendImage);

                        lock (testImagesFinal)
                        {
                            testImagesFinal.Add(testDir + blendImage);
                        }
                    });
                }
            }

            Dictionary<string, List<BenchmarkResult>> results = new Dictionary<string, List<BenchmarkResult>>();

            List<string> headers = new List<string>();

            Parallel.For(0, testImagesFinal.Count, i =>
            //for (int i = 0; i < testImagesFinal.Count; i++)
            {
                string path = testImagesFinal[i];

                List<BenchmarkResult> fileResults = new List<BenchmarkResult>();

                string nvttPath = CompressWithNVTT(targetFormat, path, runNVTT);
                fileResults.Add(benchmarkFunc(nvttPath, path, i));
                if (i == 0)
                    headers.Add("nvtt");

                string compressonatorPath = CompressWithCompressonator(targetFormat, path, false, runCompressonator);
                fileResults.Add(benchmarkFunc(compressonatorPath, path, i));
                if (i == 0)
                    headers.Add("cmp");

                string compressonatorHQPath = CompressWithCompressonator(targetFormat, path, true, runCompressonator);
                fileResults.Add(benchmarkFunc(compressonatorHQPath, path, i));
                if (i == 0)
                    headers.Add("cmp_hq");

                string directXTexHQPath = CompressWithDirectXTex(targetFormat, path, texConvCVTTPath, "_dxhq", true, true, runDXHQ);
                fileResults.Add(benchmarkFunc(directXTexHQPath, path, i));
                if (i == 0)
                    headers.Add("dxhq");

                string directXTexCPUPath = CompressWithDirectXTex(targetFormat, path, texConvCVTTPath, "_dxcpu", false, false, runDXCPU);
                fileResults.Add(benchmarkFunc(directXTexCPUPath, path, i));
                if (i == 0)
                    headers.Add("dxcpu");

                string directXTexGPUPath = CompressWithDirectXTex(targetFormat, path, texConvCVTTPath, "_dxgpu", true, false, runDX);
                fileResults.Add(benchmarkFunc(directXTexGPUPath, path, i));
                if (i == 0)
                    headers.Add("dxgpu");

                string directXTexStockPath = CompressWithDirectXTex(targetFormat, path, texConvStockPath, "_dxstock", false, false, runDXCPU_Stock);
                fileResults.Add(benchmarkFunc(directXTexStockPath, path, i));
                if (i == 0)
                    headers.Add("dxcpustock");

                string directXTexRGPath = CompressWithDirectXTex(targetFormat, path, texConvRGPath, "_dxrg", false, false, runDXCPU_Stock);
                fileResults.Add(benchmarkFunc(directXTexRGPath, path, i));
                if (i == 0)
                    headers.Add("dxcpurg");

                if (targetFormat == CompressedFormat.BC7)
                {
                    string fastcPath = CompressWithFasTC(path, runFasTC);
                    fileResults.Add(benchmarkFunc(fastcPath, path, i));
                    if (i == 0)
                        headers.Add("fastc");

                    string ispcPath = CompressWithISPC(path, runISPC);
                    fileResults.Add(benchmarkFunc(ispcPath, path, i));
                    if (i == 0)
                        headers.Add("ispc");
                }

                lock (results)
                {
                    results.Add(path, fileResults);
                }
            }
            );

            List<string> sortedFiles = new List<string>();
            foreach (string k in results.Keys)
                sortedFiles.Add(k);

            sortedFiles.Sort(delegate (string a, string b)
            {
                bool aIsAlpha = a.EndsWith("_alpha.png");
                bool bIsAlpha = b.EndsWith("_alpha.png");

                if (aIsAlpha && !bIsAlpha)
                    return -1;

                if (!aIsAlpha && bIsAlpha)
                    return 1;

                return a.CompareTo(b);
            });

            using (System.IO.StreamWriter writer = new System.IO.StreamWriter("benchmark.csv"))
            {
                writer.Write(",");
                foreach (string str in headers)
                {
                    writer.Write(str);
                    writer.Write(",,,,");
                }
                writer.WriteLine();

                writer.Write("filename");
                for (int i = 0; i < headers.Count; i++)
                    writer.Write(",error,worst,x,y");
                writer.WriteLine();

                foreach (string k in sortedFiles)
                {
                    writer.Write(k);

                    foreach (BenchmarkResult result in results[k])
                        writer.Write("," + result.error.ToString() + "," + result.worstBlock.ToString() + "," + result.worstBlockX.ToString() + "," + result.worstBlockY.ToString());

                    writer.WriteLine();
                }
            }
        }
    }
}
