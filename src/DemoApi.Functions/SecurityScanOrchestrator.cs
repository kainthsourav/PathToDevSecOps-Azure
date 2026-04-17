// src/DemoApi.Functions/SecurityScanOrchestrator.cs

using DemoApi.Functions.Models;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.DurableTask;
using Microsoft.Extensions.Logging;

namespace DemoApi.Functions;

public static class SecurityScanOrchestrator
{
    // ─────────────────────────────────────────
    // CLIENT — entry point, started by pipeline
    // ─────────────────────────────────────────
    [FunctionName("StartSecurityScan")]
    public static async Task<HttpResponseMessage> HttpStart(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = "scan/start")]
        HttpRequestMessage req,
        [DurableClient] IDurableOrchestrationClient starter,
        ILogger log)
    {
        // Read the scan request from the HTTP body
        // Your pipeline would POST this after the 'build' job completes
        var request = await req.Content!.ReadAsAsync<ScanRequest>();

        log.LogInformation(
            "Received scan request for image {ImageTag}",
            request.ImageTag);

        // Use the ImageTag as the instance ID
        // This means you can query "what is the status of image abc123?"
        // by just knowing the git SHA — same as ${{ github.sha }} in your pipeline
        string instanceId = request.ImageTag;

        await starter.StartNewAsync(
            orchestratorFunctionName: "SecurityOrchestrator",
            instanceId:               instanceId,   // ← deterministic ID
            input:                    request);

        log.LogInformation(
            "Started security scan orchestration. Instance ID: {InstanceId}",
            instanceId);

        // Returns HTTP 202 with status-check URLs automatically
        return starter.CreateCheckStatusResponse(req, instanceId);
    }

    // ─────────────────────────────────────────
    // ORCHESTRATOR — defines the scan workflow
    // ─────────────────────────────────────────
    [FunctionName("SecurityOrchestrator")]
    public static async Task<bool> RunOrchestrator(
        [OrchestrationTrigger] IDurableOrchestrationContext context,
        ILogger log)
    {
        // Get the input that was passed from the Client
        var request = context.GetInput<ScanRequest>();

        // ── STEP 1: Secret Scan ──────────────────────────────────────────
        // Maps to your Gitleaks job in security.yml
        // If this fails, we stop — no point scanning the image
        log.LogInformation("Step 1: Secret scan starting");

        var secretResult = await context.CallActivityAsync<ScanResult>(
            "SecretScan",   // ← must match [FunctionName] exactly
            request);       // ← passes the full ScanRequest to the activity

        if (!secretResult.Passed)
        {
            // Activity failed — notify and stop the whole workflow
            await context.CallActivityAsync(
                "NotifyResult",
                $"❌ Security scan FAILED for {request.ImageTag}. " +
                $"Secret scan: {secretResult.Details}");

            return false;   // orchestrator returns false = overall scan failed
        }

        // ── STEP 2: Image Scan ───────────────────────────────────────────
        // Maps to your Trivy step in app.yml security-scan job
        // Only runs if secret scan passed — same as your needs: build in app.yml
        log.LogInformation("Step 2: Image scan starting");

        var imageResult = await context.CallActivityAsync<ScanResult>(
            "ImageScan",
            request);

        if (!imageResult.Passed)
        {
            await context.CallActivityAsync(
                "NotifyResult",
                $"❌ Security scan FAILED for {request.ImageTag}. " +
                $"Image scan: {imageResult.Details}");

            return false;
        }

        // ── STEP 3: Code Quality ─────────────────────────────────────────
        // Maps to your SonarCloud step in security.yml
        log.LogInformation("Step 3: Code quality check starting");

        var qualityResult = await context.CallActivityAsync<ScanResult>(
            "CodeQuality",
            request);

        if (!qualityResult.Passed)
        {
            await context.CallActivityAsync(
                "NotifyResult",
                $"❌ Security scan FAILED for {request.ImageTag}. " +
                $"Code quality: {qualityResult.Details}");

            return false;
        }

        // ── ALL PASSED ───────────────────────────────────────────────────
        await context.CallActivityAsync(
            "NotifyResult",
            $"✅ All security scans PASSED for {request.ImageTag}. " +
            $"Safe to deploy to AKS.");

        return true;    // pipeline can now proceed with deployment
    }
}