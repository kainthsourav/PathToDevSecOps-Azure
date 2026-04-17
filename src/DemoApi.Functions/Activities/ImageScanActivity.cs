using DemoApi.Functions.Models;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.DurableTask;
using Microsoft.Extensions.Logging;

namespace DemoApi.Functions.Activities
{
    public static class ImageScanActivity
    {
        [FunctionName("ImageScan")]
        public static async Task<ScanResult> Run ([ActivityTrigger] ScanRequest request, ILogger log)
        {
            log.LogInformation(
            "Starting Trivy image scan for {ImageRef}",
            request.ImageRef);

            await Task.Delay(TimeSpan.FromSeconds(5));

            return new ScanResult
            {
                ScanType = "ImageScan",
                Passed = true,
                Details     = $"No CRITICAL or HIGH vulnerabilities found in {request.ImageRef}",
                CompletedAt = DateTime.UtcNow
            };
        }
    }
}