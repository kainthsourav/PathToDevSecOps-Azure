using System.Runtime.CompilerServices;

using DemoApi.Functions.Models;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.DurableTask;
using Microsoft.Extensions.Logging;

namespace DemoApi.Functions.Activities
{
    public static class SecretScanActivity
    {
       [FunctionName("SecretScan")]
       public static async Task<ScanResult> Run([ActivityTrigger] ScanRequest request, ILogger log)
        {
            log.LogInformation(
            "Starting secret scan for image tag {ImageTag} on branch {Branch}",
            request.ImageTag,
            request.Branch);

            await Task.Delay(TimeSpan.FromSeconds(5));

            var passed=!request.branch.contains("test-leak");
            return new ScanResult
            {
                ScanType = "SecretScan",
                Passed = passed,
                Details = passed ? "No secrets found." : "Secrets detected in the image.",
                CompletedAt = DateTime.UtcNow
            };
        }
    }
}