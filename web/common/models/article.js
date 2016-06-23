'use strict';

const child = require('child_process');

module.exports = function(Article) {
	Article.disambiguate = function(article, cb) {
		let script = __dirname + '/../../../../pruebas/script.R';
		var R = child.exec('Rscript ' + script, (error, stdout, stderr) => {
			if (error) {
				cb(error);
			} else {
				let results = [{
					author: 'Name',
					articles: ['1', '2']
				}, {
					author: 'Name2',
					articles: ['3', '2']
				}];
				cb(null, results);
			}
		});
	};
	Article.remoteMethod('disambiguate', {
		accepts: {
			arg: 'article',
			type: 'object',
			required: true
		},
		returns: {
			arg: 'authors',
			type: 'array'
		}
	});
};