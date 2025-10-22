using System;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;
using System.Media;
using System.Runtime.InteropServices;

namespace FoxyJumpScare
{
    internal class Program
    {
        private static bool changeSystemVolume = true;

        [STAThread]
        static void Main(string[] args)
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            var form = new Form();
            form.WindowState = FormWindowState.Maximized;
            form.FormBorderStyle = FormBorderStyle.None;
            form.BackColor = Color.Black;
            form.AllowTransparency = true;
            form.TransparencyKey = Color.Black;

            var pictureBox = new PictureBox();
            pictureBox.Dock = DockStyle.Fill;
            pictureBox.SizeMode = PictureBoxSizeMode.StretchImage;
            pictureBox.BackColor = Color.Black;
            pictureBox.Margin = new Padding(0);
            pictureBox.Padding = new Padding(0);
            form.Controls.Add(pictureBox);

            var images = new List<Image>();
            for (int i = 0; i <= 13; i++)
            {
                string name = "frame" + i.ToString(i < 10 ? "D3" : "D4");
                var bmp = assets.ResourceManager.GetObject(name) as Bitmap;
                images.Add(bmp);
            }

            var soundStream = assets.ResourceManager.GetStream("jumpscare");
            var soundPlayer = new SoundPlayer(soundStream);

            if (changeSystemVolume)
            {

            }

            SetVolume(100);

            int currentFrame = 0;
            var timer = new Timer();
            timer.Interval = 1000 / 30; // 30fps
            timer.Tick += (s, e) =>
            {
                if (currentFrame < images.Count)
                {
                    pictureBox.Image = images[currentFrame];
                    currentFrame++;
                }
                else
                {
                    timer.Stop();
                    Application.Exit();
                }
            };

            form.Shown += (s, e) =>
            {
                soundPlayer.Play();
                timer.Start();
            };

            Application.Run(form);
        }

        [DllImport("winmm.dll")]
        public static extern int waveOutSetVolume(IntPtr hwo, uint dwVolume);

        public static void SetVolume(int volume)
        {
            uint vol = (uint)((volume / 100.0) * 65535);
            uint volumeBoth = vol | (vol << 16);
            waveOutSetVolume(IntPtr.Zero, volumeBoth);
        }
    }
}