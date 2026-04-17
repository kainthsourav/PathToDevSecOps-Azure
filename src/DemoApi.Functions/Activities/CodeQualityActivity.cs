// src/DemoApi.Functions/Activities/CodeQualityActivity.cs

using DemoApi.Functions.Models;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.DurableTask;
using Microsoft.Extensions.Logging;

namespace DemoApi.Functions.Activities;

public static class CodeQualityActivity
{
    [FunctionName("CodeQuality")]
    public static async Task<ScanResult> Run(
        [ActivityTrigger] ScanRequest request,
        ILogger log)
    {
        log.LogInformation(
            "Starting SonarCloud quality gate check for {ImageTag}",
            request.ImageTag);

        // In production: call SonarCloud API to check quality gate status
        // GET https://sonarcloud.io/api/qualitygates/project_status?projectKey=...
        await Task.Delay(TimeSpan.FromSeconds(2));

        return new ScanResult
        {
            ScanType    = "CodeQuality",
            Passed      = true,
            Details     = "Quality gate passed. Coverage 82%, 0 bugs, 0 vulnerabilities",
            CompletedAt = DateTime.UtcNow
        };
    }
}