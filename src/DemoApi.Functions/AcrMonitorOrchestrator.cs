using DemoApi.Functions.Models;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.DurableTask;
using Microsoft.Extensions.Logging;

namespace DemoApi.Functions;

public static class AcrMonitorOrchestrator
{
    // Static HttpClient — reused across invocations, avoids socket exhaustion
    private static readonly HttpClient _httpClient = new();

    // ── ORCHESTRATOR ──────────────────────────────────────────────────────
    [FunctionName("AcrMonitorOrchestrator")]
    public static async Task<bool> RunOrchestrator(
        [OrchestrationTrigger] IDurableOrchestrationContext context)
    {
        // CreateReplaySafeLogger — only logs once per step, not on every replay
        ILogger log = context.CreateReplaySafeLogger(nameof(AcrMonitorOrchestrator));

        var request = context.GetInput<ScanRequest>();

        var pollingInterval = TimeSpan.FromSeconds(30);
        var expiryTime      = context.CurrentUtcDateTime.Add(TimeSpan.FromMinutes(10));

        while (context.CurrentUtcDateTime < expiryTime)
        {
            var imageReady = await context.CallActivityAsync<bool>(
                "CheckImageInAcr",
                request.ImageRef);

            if (imageReady)
            {
                log.LogInformation(
                    "Image {ImageRef} confirmed in ACR. Safe to deploy.",
                    request.ImageRef);

                return true;
            }

            var nextCheck = context.CurrentUtcDateTime.Add(pollingInterval);
            await context.CreateTimer(nextCheck, CancellationToken.None);
        }

        log.LogWarning(
            "Image {ImageRef} not found in ACR after 10 minutes. Deployment blocked.",
            request.ImageRef);

        return false;
    }

    // ── ACTIVITY ──────────────────────────────────────────────────────────
    [FunctionName("CheckImageInAcr")]
    public static async Task<bool> CheckImageInAcr(
        [ActivityTrigger] string imageRef,
        ILogger log)   // ← ILogger IS valid in activities, just not in orchestrators
    {
        log.LogInformation("Checking ACR for image {ImageRef}", imageRef);

        try
        {
            var parts     = imageRef.Split('/');
            var registry  = parts[0];
            var repoTag   = string.Join("/", parts[1..]);
            var repoParts = repoTag.Split(':');
            var repo      = repoParts[0];
            var tag       = repoParts[1];

            var manifestUrl = $"https://{registry}/v2/{repo}/manifests/{tag}";
            var response    = await _httpClient.GetAsync(manifestUrl);

            return response.IsSuccessStatusCode;
        }
        catch (Exception ex)
        {
            log.LogWarning("ACR check failed: {Error}. Will retry.", ex.Message);
            return false;
        }
    }
}