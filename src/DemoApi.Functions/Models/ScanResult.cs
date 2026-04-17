namespace DemoApi.Functions.Models
{
    public class ScanRequest
    {
        public string ScanType { get; set; } = string.Empty;
        public bool Passed { get; set; }
        public string Details { get; set; } = string.Empty;
        public DateTime CompletedAt { get; set; }
    }
}