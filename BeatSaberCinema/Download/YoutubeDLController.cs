using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading;
using IPA.Utilities;

namespace BeatSaberCinema
{
	public abstract class YoutubeDLController
	{
		private readonly string _youtubeDLFilepath = FindTool("yt-dlp.exe");
		private readonly string _ffmpegFilepath = FindTool("ffmpeg.exe");
		private readonly string _denoFilepath = FindTool("deno.exe");
		private readonly string _youtubeDLConfigFilepath = Path.Combine(UnityGame.UserDataPath, "youtube-dl.conf");

		private static string FindTool(string name)
		{
			var canonical = Path.Combine(UnityGame.ModLibrariesPath, name);
			var nested = Path.Combine(UnityGame.ModLibrariesPath, "Cinema", name);
			return File.Exists(canonical) || !File.Exists(nested) ? canonical : nested;
		}

		public string MissingLibraries => string.Join(", ", new[] { _youtubeDLFilepath, _ffmpegFilepath, _denoFilepath }
			.Where(path => !File.Exists(path)).Select(Path.GetFileName));

		public bool LibrariesAvailable() => string.IsNullOrEmpty(MissingLibraries);

		private static string GetConfigFileArgument(string path)
		{
			return !File.Exists(path) ? " --ignore-config" : $" --config-location \"{path}\"";
		}

		protected static void DisposeProcess(Process? process)
		{
			if (process == null)
			{
				return;
			}

			int processId;
			try
			{
				processId = process.Id;
			} catch (Exception)
			{
				return;
			}

			Log.Debug($"[{processId}] Cleaning up process");

			void WorkDelegate()
			{
				try
				{
					if (!process.HasExited)
					{
						process.Kill();
					}
				}
				catch (Exception exception)
				{
					if (!exception.Message.Contains("The operation completed successfully") &&
					    !exception.Message.Contains("No process is associated with this object."))
					{
						Log.Warn(exception);
					}
				}

				try
				{
					process.Dispose();
				}
				catch (Exception exception)
				{
					Log.Warn(exception);
				}
			}

			var thread = new Thread((ThreadStart) WorkDelegate);
			thread.Start();
		}

		protected Process CreateProcess(string arguments, string? workingDirectory = null)
		{
			//Use config file in UserData instead of the global yt-dl one
			arguments += GetConfigFileArgument(_youtubeDLConfigFilepath);
			arguments += $" --ffmpeg-location \"{Path.GetDirectoryName(_ffmpegFilepath)}\"";
			arguments += $" --js-runtimes \"deno:{_denoFilepath}\"";

			var process = new Process
			{
				StartInfo =
				{
					FileName = _youtubeDLFilepath,
					Arguments = arguments,
					RedirectStandardOutput = true,
					RedirectStandardError = true,
					UseShellExecute = false,
					CreateNoWindow = true,
					WorkingDirectory = workingDirectory ?? string.Empty
				},
				EnableRaisingEvents = true,
				PriorityBoostEnabled = true
			};
			process.Disposed += OnProcessDisposed;

			return process;
		}

		protected static void StartProcessThreaded(Process process)
		{
			void WorkDelegate()
			{
				var timer = new Stopwatch();
				timer.Start();
				var ret = process.Start();
				process.BeginOutputReadLine();
				process.BeginErrorReadLine();
				Log.Debug($"Starting thread took {timer.Elapsed.TotalMilliseconds}ms");
				if (!ret)
				{
					Log.Error("Failed to start thread");
				}
			}

			var thread = new Thread((ThreadStart) WorkDelegate);
			thread.Start();
		}

		protected static bool IsProcessRunning(Process? process)
		{
			try
			{
				return process is { HasExited: false };
			}
			catch (Exception e)
			{
				if (!(e is InvalidOperationException))
				{
					Log.Warn(e);
				}
			}

			return false;
		}

		private static void OnProcessDisposed(object sender, EventArgs eventArgs)
		{
			Log.Debug("Process disposed");
		}
	}
}
