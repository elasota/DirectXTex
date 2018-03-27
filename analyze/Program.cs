using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Drawing;

namespace analyze
{
    class Program
    {
        static string texConvPath = "Texconv\\bin\\Desktop_2017\\x64\\Release\\texconv.exe";

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

        static BenchmarkResult Benchmark(string compressedPath, string originalPath, int uid)
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

        static string CompressWithCompressonator(string path, bool hq, bool run)
        {
            string compressonatorPath = "C:\\Program Files\\Compressonator\\CompressonatorCLI.exe";

            string resultPath = path.Replace(".png", hq ? "_chq.dds" : "_c.dds");

            if (run)
            {
                string args = "-nomipmap -fd BC7 ";

                if (hq)
                    args += "-Quality 1.0 ";

                RunProcess(compressonatorPath, args + path + " " + resultPath);
            }

            return resultPath;
        }

        static string CompressWithNVTT(string path, bool run)
        {
            string nvttPath = "tests\\nvtt\\nvcompress.exe";

            string resultPath = path.Replace(".png", "_nvtt.dds");

            if (run)
                RunProcess(nvttPath, "-bc7 -nomips -alpha " + path + " " + resultPath);

            return resultPath;
        }

        static string CompressWithDirectXTex(string path, bool useGPU, bool useHQ, bool run)
        {
            string resultPath = path.Replace(".png", "");
            if (useGPU)
            {
                if (useHQ)
                    resultPath += "_dxhq";
                else
                    resultPath += "_dxgpu";
            }
            else
                resultPath += "_dxcpu";
            resultPath += ".dds";

            if (run)
            {
                string args = "-srgbi -srgbo -m 1 -f BC7_UNORM -y -bcmax -bcuniform ";
                if (!useGPU)
                    args += "-nogpu ";
                if (useHQ)
                    args += "-bchq ";
                args += path;

                RunProcess(texConvPath, args);

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

            string resultPath = path.Replace(".png", "_fastc.dds");

            if (run)
                RunProcess(fastcPath, path + " " + resultPath);

            return resultPath;
        }

        static string CompressWithISPC(string path, bool run)
        {
            string fastcPath = "x64\\Release\\ISPCTextureCompressor.exe";

            string resultPath = path.Replace(".png", "_ispc.dds");

            if (run)
                RunProcess(fastcPath, path + " " + resultPath);

            return resultPath;
        }

        static void Main(string[] args)
        {
            bool runCompressonator = false;
            bool runNVTT = false;
            bool runDXCPU = false;
            bool runDX = false;
            bool runDXHQ = true;
            bool runFasTC = false;
            bool runISPC = false;
            bool runConversions = false;

            string[] testImages = {
                "kodim01.png", "kodim02.png", "kodim03.png", "kodim04.png", "kodim05.png", "kodim06.png",
                "kodim07.png", "kodim08.png", "kodim09.png", "kodim10.png", "kodim11.png", "kodim12.png",
                "kodim13.png", "kodim14.png", "kodim15.png", "kodim16.png", "kodim17.png", "kodim18.png",
                "kodim19.png", "kodim20.png", "kodim21.png", "kodim22.png", "kodim23.png", "kodim24.png" };

            string testDir = "tests\\";


            Dictionary<ImageDimensions, List<string>> imagesBySize = new Dictionary<ImageDimensions, List<string>>();

            List<string> testImagesFinal = new List<string>();

            foreach (string path in testImages)
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

                testImagesFinal.Add(testDir + path);
            }

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

            Dictionary<string, List<BenchmarkResult>> results = new Dictionary<string, List<BenchmarkResult>>();

            Parallel.For(0, testImagesFinal.Count, i =>
            //for (int i = 0; i < testImagesFinal.Count; i++)
            {
                string path = testImagesFinal[i];

                List<BenchmarkResult> fileResults = new List<BenchmarkResult>();

                string nvttPath = CompressWithNVTT(path, runNVTT);
                fileResults.Add(Benchmark(nvttPath, path, i));

                string compressonatorPath = CompressWithCompressonator(path, false, runCompressonator);
                fileResults.Add(Benchmark(compressonatorPath, path, i));

                string compressonatorHQPath = CompressWithCompressonator(path, true, runCompressonator);
                fileResults.Add(Benchmark(compressonatorHQPath, path, i));

                string directXTexHQPath = CompressWithDirectXTex(path, true, true, runDXHQ);
                fileResults.Add(Benchmark(directXTexHQPath, path, i));

                string directXTexCPUPath = CompressWithDirectXTex(path, false, false, runDXCPU);
                fileResults.Add(Benchmark(directXTexCPUPath, path, i));

                string directXTexGPUPath = CompressWithDirectXTex(path, true, false, runDX);
                fileResults.Add(Benchmark(directXTexGPUPath, path, i));

                string fastcPath = CompressWithFasTC(path, runFasTC);
                fileResults.Add(Benchmark(fastcPath, path, i));

                string ispcPath = CompressWithISPC(path, runISPC);
                fileResults.Add(Benchmark(ispcPath, path, i));

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
                writer.WriteLine(",nvtt,,,,compressonator,,,,compressonator_hq,,,,dxhq,,,,dxcpu,,,,dxgpu,,,,fastc,,,,ispc_slow,,,,");
                writer.Write("filename");
                for (int i = 0; i < 8; i++)
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
