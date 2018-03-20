#r "Newtonsoft.Json"

using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using Newtonsoft.Json.Linq;
using System.Net.Http.Formatting;

public static async Task<HttpResponseMessage> Run(HttpRequestMessage req, TraceWriter log)
{
    log.Info("C# HTTP trigger function processed a request.");

    // Get request body
    dynamic data = await req.Content.ReadAsAsync<object>();
    string pat = data?.pat;
    string instance = data?.instance;
    string taskGuid = data?.taskguid;
    string version = data?.version;

    if ((pat == null ) ||
        (instance == null) ||
        (taskGuid == null) ||
        (version == null))
    {
        log.Info("Invalid parameters passed");
        return req.CreateResponse(HttpStatusCode.BadRequest, "Please pass a VSTS instance name, PAT and TaskGuid in the request body");
    } 

    try
    {
        log.Info($"Requesting deployed task with GUID {taskGuid} to see if it is version {version} from VSTS instance {instance}");

        var client = new HttpClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Basic",
            Convert.ToBase64String(
                System.Text.ASCIIEncoding.ASCII.GetBytes(
                string.Format("{0}:{1}", "", pat))));

        client.BaseAddress = new Uri($"https://{instance}.visualstudio.com/_apis/distributedtask/tasks/{taskGuid}");
        var result = await client.GetAsync("");
        string resultContent = await result.Content.ReadAsStringAsync();

        var o= JObject.Parse(resultContent);
        var isDeployed = new { Deployed = version.Equals(o.SelectToken("value")[0].SelectToken("contributionVersion").ToString()) };
        
        log.Info($"The response payload is {isDeployed}");

        return req.CreateResponse(
            HttpStatusCode.OK,
            isDeployed,
            JsonMediaTypeFormatter.DefaultMediaType);
    } catch (Exception ex)
    {
       return req.CreateResponse(HttpStatusCode.BadRequest, $"Exception thrown making API call or Parsing result. {ex.Message}");
    }
}
