'use strict';

var loopback = require('loopback');
var boot = require('loopback-boot');
const child = require('child_process');

var app = module.exports = loopback();

app.start = function() {
  // start the web server
  return app.listen(function() {
    app.emit('started');
    var baseUrl = app.get('url').replace(/\/$/, '');
    console.log('Web server listening at: %s', baseUrl);
    if (app.get('loopback-component-explorer')) {
      var explorerPath = app.get('loopback-component-explorer').mountPath;
      console.log('Browse your REST API at %s%s', baseUrl, explorerPath);
    }
  });
};

// Bootstrap the application, configure models, datasources and middleware.
// Sub-apps like REST API are mounted via boot scripts.
boot(app, __dirname, function(err) {
  if (err) throw err;

  // start the server if `$ node server.js`
  if (require.main === module) {
    // app.start();
    app.io = require('socket.io')(app.start());
    app.io.on('connection', function(socket) {
      console.log('connection ' + socket.id);
      socket.on('process', function(process_id) {
        console.log(process_id);
        let script = __dirname + '/../../Operational/Process_Web_Article.R ';
        var R = child.spawn('Rscript', [script, process_id]);
        R.stdout.on('data', data => {
          socket.emit('output', data.toString());
        });
        R.stderr.on('data', data => {
          socket.emit('output', data.toString());
        });
        R.on('close', code => {
          console.log(code);
          if (code == 0) {
            /*let results = [{
              author: 'Name',
              articles: ['1', '2']
            }, {
              author: 'Name2',
              articles: ['3', '2']
            }];*/
            let query = `
              select
	aa1.d as d1,
	a2.title
from
	source.articles a
	join main.same_authors sa on a.id = sa.id1
	join main.articles_authors aa1 on sa.id1 = aa1.id and sa.d1 = aa1.d
	left join main.articles_authors aa2 on sa.id2 = aa2.id and sa.d2 = aa2.d
	left join source.articles a2 on sa.id2 = a2.id
where
	a.processid = 10014
	and sa.same is true
order by aa1.id, aa1.d, aa2.id, aa2.d
limit 500;
            	`;
            app.dataSources.ArticlesDB.connector.execute(query, function(err, results) {
              socket.emit('results', JSON.stringify(results));
            });
          } else {
            socket.emit('err');
          }
        });
      });
    });
  }
});