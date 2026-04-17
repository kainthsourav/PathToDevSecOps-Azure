// src/DemoApi.Functions/AcrMonitorOrchestrator.cs

[FunctionName("AcrMonitorOrchestrator")]
public static async Task<bool> RunOrchestrator(
    [OrchestrationTrigger] IDurableOrchestrationContext context,
    ILogger log)
{
    var request = context.GetInput<ScanRequest>();  // reusing ScanRequest — ImageRef tells us what to look for

    // How long to wait between checks
    var pollingInterval = TimeSpan.FromSeconds(30);

    // Give up after this long — maps to your -lock-timeout=10m in Terraform
    var expiryTime = context.CurrentUtcDateTime.Add(TimeSpan.FromMinutes(10));

    // ── MONITOR LOOP ─────────────────────────────────────────────────────
    while (context.CurrentUtcDateTime < expiryTime)
    {
        // Ask the activity: is this image pullable from ACR yet?
        var imageReady = await context.CallActivityAsync<bool>(
            "CheckImageInAcr",
            request.ImageRef);

        if (imageReady)
        {
            log.LogInformation(
                "Image {ImageRef} confirmed in ACR. Safe to deploy.",
                request.ImageRef);

            return true;    // signal pipeline: proceed with deploy
        }

        // Not ready yet — wait 30 seconds then check again
        // context.CreateTimer is replay-safe — DateTime.UtcNow would NOT be
        var nextCheck = context.CurrentUtcDateTime.Add(pollingInterval);
        await context.CreateTimer(nextCheck, CancellationToken.None);

        // After timer fires, loop back and check again
        // Each iteration: checkpoint → stop → wait → replay → continue
    }

    // Timed out — image never appeared
    log.LogWarning(
        "Image {ImageRef} not found in ACR after 10 minutes. Deployment blocked.",
        request.ImageRef);

    return false;
}

// ── ACTIVITY: Check if image exists in ACR ────────────────────────────────
[FunctionName("CheckImageInAcr")]
public static async Task<bool> CheckImageInAcr(
    [ActivityTrigger] string imageRef,   // e.g. acrdemosouravstaging.azurecr.io/demoapi:abc123
    ILogger log)
{
    log.LogInformation("Checking ACR for image {ImageRef}", imageRef);

    // In production: use Azure SDK to check if manifest exists
    // var credential = new DefaultAzureCredential();
    // var client = new ContainerRegistryClient(new Uri($"https://{registryHost}"), credential);
    // var artifact = client.GetArtifact(repositoryName, tag);
    // var properties = await artifact.GetManifestPropertiesAsync();

    // For now: simulate with HTTP check against ACR manifest endpoint
    using var httpClient = new HttpClient();
    try
    {
        var parts     = imageRef.Split('/');
        var registry  = parts[0];   // acrdemosouravstaging.azurecr.io
        var repoTag   = string.Join("/", parts[1..]);   // demoapi:abc123
        var repoParts = repoTag.Split(':');
        var repo      = repoParts[0];   // demoapi
        var tag       = repoParts[1];   // abc123

        // ACR manifest endpoint returns 200 if image exists, 404 if not
        var manifestUrl = $"https://{registry}/v2/{repo}/manifests/{tag}";
        var response    = await httpClient.GetAsync(manifestUrl);

        return response.IsSuccessStatusCode;
    }
    catch (Exception ex)
    {
        log.LogWarning("ACR check failed: {Error}. Will retry.", ex.Message);
        return false;   // treat errors as not-ready, loop will retry
    }
}