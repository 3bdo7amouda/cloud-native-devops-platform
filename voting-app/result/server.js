var express = require('express'),
    async = require('async'),
    { MongoClient } = require('mongodb'),
    cookieParser = require('cookie-parser'),
    path = require('path'),
    app = express(),
    server = require('http').Server(app),
    io = require('socket.io')(server);

var port = process.env.PORT || 4000;

io.on('connection', function (socket) {

  socket.emit('message', { text : 'Welcome!' });

  socket.on('subscribe', function (data) {
    socket.join(data.channel);
  });
});

// MongoDB connection string from environment variable
var mongoUrl = process.env.MONGODB_URI || 'mongodb://localhost:27017';
console.log('MongoDB URL configured:', mongoUrl.replace(/:[^:@]+@/, ':****@')); // Hide password

// MongoDB client with timeout options
var client = new MongoClient(mongoUrl, {
  serverSelectionTimeoutMS: 5000,
  connectTimeoutMS: 10000,
});

// Connect to MongoDB
console.log('Connecting to MongoDB...');
client.connect()
  .then(() => {
    console.log("Connected to MongoDB successfully!");
    const db = client.db('voting');
    const collection = db.collection('votes');
    console.log('Starting to query votes from MongoDB...');
    getVotes(collection);
  })
  .catch((err) => {
    console.error("Failed to connect to MongoDB:", err.message);
    console.error("Retrying in 5 seconds...");
    setTimeout(() => {
      process.exit(1); // Exit and let Kubernetes restart the pod
    }, 5000);
  });

function getVotes(collection) {
  console.log('getVotes() called - querying MongoDB...');
  
  collection.aggregate([
    { $group: { _id: "$vote", count: { $sum: 1 } } }
  ]).toArray()
    .then((result) => {
      console.log('Query result:', JSON.stringify(result));
      var votes = collectVotesFromResult(result);
      console.log('Emitting scores:', JSON.stringify(votes));
      io.sockets.emit("scores", JSON.stringify(votes));
      
      setTimeout(function() {getVotes(collection) }, 1000);
    })
    .catch((err) => {
      console.error("Error performing query:", err.message);
      setTimeout(function() {getVotes(collection) }, 1000);
    });
}

function collectVotesFromResult(result) {
  var votes = {a: 0, b: 0};

  result.forEach(function (row) {
    votes[row._id] = parseInt(row.count);
  });

  return votes;
}

app.use(cookieParser());
app.use(express.urlencoded());
app.use(express.static(__dirname + '/views'));

app.get('/', function (req, res) {
  res.sendFile(path.resolve(__dirname + '/views/index.html'));
});

server.listen(port, function () {
  var port = server.address().port;
  console.log('App running on port ' + port);
});
