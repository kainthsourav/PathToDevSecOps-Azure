// src/DemoApi.Functions/Activities/NotifyActivity.cs

using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.DurableTask;
using Microsoft.Extensions.Logging;

namespace DemoApi.Functions.Activities;

public static class NotifyActivity
{
    [FunctionName("NotifyResult")]
    public static Task Run(
        [ActivityTrigger] string message,   // ← simple string input this time
        ILogger log)
    {
        // In production: post to Teams/Slack, send email, update GitHub commit status
        log.LogInformation("NOTIFICATION: {Message}", message);
        return Task.CompletedTask;
    }
}