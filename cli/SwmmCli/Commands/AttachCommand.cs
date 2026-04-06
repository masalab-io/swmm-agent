using System.CommandLine;
using SwmmCli.IO;
using SwmmCli.Session;

namespace SwmmCli.Commands;

static class AttachCommand
{
    public static Command Build()
    {
        var pidArg = new Argument<int>("pid", "PID of the SWMM process to attach to");
        var cmd = new Command("attach", "Attach to a SWMM process and save the session");
        cmd.AddArgument(pidArg);
        cmd.SetHandler((int pid) =>
        {
            SessionStore.WritePid(pid);
            NdJson.WriteSession(pid);
        }, pidArg);
        return cmd;
    }
}
