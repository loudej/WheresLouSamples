using System;  
using Microsoft.Framework.ConfigurationModel;

public class Program  
{
    public void Main(string[] args) 
    {
        var config = new Configuration()
            .AddIniFile("App_Data\\config.ini")
            .AddJsonFile("App_Data\\config.json")
            .AddXmlFile("App_Data\\config.xml")
            .AddEnvironmentVariables()
            .AddCommandLine(args);

        Console.WriteLine(
            "size:{0} color:{1} background:{2}",
            config.Get("Display:Font:Size"),
            config.Get("Display:Font:Color"),
            config.Get("Display:Font:Background")
        );
    }
}
