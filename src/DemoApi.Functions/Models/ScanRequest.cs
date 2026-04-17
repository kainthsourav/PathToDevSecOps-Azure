namespace DemoApi.Functions.Models
{
    public class ScanRequest
    {
        public string ImageTag { get; set; } = string.Empty;
        public string ImageRef { get; set; } = string.Empty;
        public string Branch { get; set; } = string.Empty;
    }
}