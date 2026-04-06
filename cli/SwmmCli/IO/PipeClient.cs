using System.Diagnostics;
using System.IO.Pipes;
using System.Text;
using System.Text.Json;

namespace SwmmCli.IO;

/// <summary>
/// Sends a single JSON command to the SWMM named pipe and prints the response.
/// </summary>
static class PipeClient
{
    /// <summary>
    /// Sends <paramref name="requestJson"/> and returns the raw response string.
    /// Throws on pipe error or timeout.
    /// </summary>
    public static async Task<string> SendRawAsync(int pid, string requestJson)
    {
        string pipeName = $"swmm_agent_{pid}";
        using var pipe = new NamedPipeClientStream(".", pipeName, PipeDirection.InOut,
            PipeOptions.Asynchronous);

        using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
        try
        {
            await pipe.ConnectAsync(cts.Token);
        }
        catch (OperationCanceledException)
        {
            var swmmProcs = Process.GetProcessesByName("Epaswmm5");
            string msg = "Pipe connect timeout — is SWMM running with the agent?";
            if (swmmProcs.Length > 1)
                msg += $" Note: {swmmProcs.Length} Epaswmm5.exe instances are running — specify --pid to target one.";
            throw new Exception(msg);
        }

        byte[] payload = Encoding.UTF8.GetBytes(requestJson + "\n");
        await pipe.WriteAsync(payload);
        await pipe.FlushAsync();

        var sb = new StringBuilder();
        byte[] buf = new byte[4096];
        while (true)
        {
            int bytesRead = await pipe.ReadAsync(buf);
            if (bytesRead == 0) break;
            string chunk = Encoding.UTF8.GetString(buf, 0, bytesRead);
            sb.Append(chunk);
            if (chunk.Contains('\n')) break;
        }

        return sb.ToString().TrimEnd('\n', '\r');
    }

    /// <summary>
    /// Sends <paramref name="requestJson"/>, prints the response, and returns an exit code.
    /// </summary>
    public static async Task<int> SendAsync(int pid, string requestJson)
    {
        try
        {
            string raw = await SendRawAsync(pid, requestJson);
            Console.WriteLine(raw);
            return 0;
        }
        catch (Exception ex)
        {
            Console.WriteLine(JsonSerializer.Serialize(new { ok = false, error = ex.Message }));
            return 1;
        }
    }
}
