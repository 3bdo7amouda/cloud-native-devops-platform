using System;
using System.Data.Common;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using Newtonsoft.Json;
using MongoDB.Driver;
using MongoDB.Bson;
using StackExchange.Redis;

namespace Worker
{
    public class Program
    {
        public static int Main(string[] args)
        {
            try
            {
                var mongoCollection = OpenMongoConnection();
                var redisHost = Environment.GetEnvironmentVariable("REDIS_HOST") ?? "redis";
                var redisConn = OpenRedisConnection(redisHost);
                var redis = redisConn.GetDatabase();

                var definition = new { vote = "", voter_id = "" };
                while (true)
                {
                    // Slow down to prevent CPU spike, only query each 100ms
                    Thread.Sleep(100);

                    // Reconnect redis if down
                    if (redisConn == null || !redisConn.IsConnected) {
                        Console.WriteLine("Reconnecting Redis");
                        redisConn = OpenRedisConnection(redisHost);
                        redis = redisConn.GetDatabase();
                    }
                    string json = redis.ListLeftPopAsync("votes").Result;
                    if (json != null)
                    {
                        var vote = JsonConvert.DeserializeAnonymousType(json, definition);
                        Console.WriteLine($"Processing vote for '{vote.vote}' by '{vote.voter_id}'");
                        UpdateVote(mongoCollection, vote.voter_id, vote.vote);
                    }
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine(ex.ToString());
                return 1;
            }
        }

        private static IMongoCollection<BsonDocument> OpenMongoConnection()
        {
            // Get MongoDB connection string from environment variable
            var connectionString = Environment.GetEnvironmentVariable("MONGODB_URI") 
                ?? "mongodb://localhost:27017";
            
            while (true)
            {
                try
                {
                    var client = new MongoClient(connectionString);
                    var database = client.GetDatabase("voting");
                    var collection = database.GetCollection<BsonDocument>("votes");
                    
                    // Test connection
                    database.RunCommand<BsonDocument>(new BsonDocument("ping", 1));
                    Console.Error.WriteLine("Connected to MongoDB");
                    
                    return collection;
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"Waiting for MongoDB: {ex.Message}");
                    Thread.Sleep(1000);
                }
            }
        }

        private static ConnectionMultiplexer OpenRedisConnection(string hostname)
        {
            // Use IP address to workaround https://github.com/StackExchange/StackExchange.Redis/issues/410
            var ipAddress = GetIp(hostname);
            Console.WriteLine($"Found redis at {ipAddress}");

            while (true)
            {
                try
                {
                    Console.Error.WriteLine("Connecting to redis");
                    return ConnectionMultiplexer.Connect(ipAddress);
                }
                catch (RedisConnectionException)
                {
                    Console.Error.WriteLine("Waiting for redis");
                    Thread.Sleep(1000);
                }
            }
        }

        private static string GetIp(string hostname)
            => Dns.GetHostEntryAsync(hostname)
                .Result
                .AddressList
                .First(a => a.AddressFamily == AddressFamily.InterNetwork)
                .ToString();

        private static void UpdateVote(IMongoCollection<BsonDocument> collection, string voterId, string vote)
        {
            try
            {
                var filter = Builders<BsonDocument>.Filter.Eq("_id", voterId);
                var update = Builders<BsonDocument>.Update
                    .Set("vote", vote)
                    .SetOnInsert("_id", voterId)
                    .SetOnInsert("created_at", DateTime.UtcNow);
                
                collection.UpdateOne(
                    filter, 
                    update, 
                    new UpdateOptions { IsUpsert = true }
                );
                
                Console.WriteLine($"Updated vote for {voterId}: {vote}");
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error updating vote: {ex.Message}");
            }
        }
    }
}