var express = require("express");
var mysql = require("mysql");
var db = require("./server"); // Importă conexiunea MySQL
var app = express();

app.get('/', function(req, res){
    let sql = "SELECT * FROM interphoneapp_database.users";
    connection.query(sql, function(err,results){
        if(err) throw (err); 
        res.send(results); 
    });

});

// Port corectat și mesaj de debug
var PORT = 3001;
app.listen(PORT, function(){
    console.log(`🚀 Server running at http://localhost:${PORT}`);
    connection.connect(function(err){
        if(err) throw (err);
        console.log('✅ Conectat la baza de date MySQL!')
    })
});