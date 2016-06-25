'use strict';

const child = require('child_process');

module.exports = function(Article) {
	Article.disambiguate = function(article, cb) {
		if (!article.title) {
			cb(new Error('Title is missing'));
		} else if (!article.authors || article.authors.length < 1) {
			cb(new Error('Authors are missing'));
		} else if (!article.keywords || article.keywords.length < 1) {
			cb(new Error('Keywords are missing'));
		} else if (!article.subjects || article.subjects.length < 1) {
			cb(new Error('Subjects are missing'));
		} else if (!article.references || article.references.length < 1) {
			cb(new Error('References are missing'));
		} else {
			let pid = new Date().getTime(),
				title = article.title,
				journal = article.journal || '',
				year = article.year || null;
			Article.dataSource.connector.execute("select greatest(900000, max(id))+1 as id from source.articles", function(error, result) {
				let id = result[0].id;
				console.log(id);
				let query = `
insert into source.articles
values ((select max(processid)+1 from source.articles), ${id}, '${title}', '${journal}', null, null, ${year});
`;
				for (let i in article.authors) {
					let author = article.authors[i];
					query += `
				insert into source.signatures 
				values (${id}, ${i}, '${author.first_name}', '${author.first_name.substr(0,1)}', '${author.middle_name.substr(0,1)}', '${author.last_name}', '${author.middle_name}');
				`;
				}
				for (let keyword of article.keywords) {
					query += `
					insert into source.keywords
					values (${id}, 'WEB', '${keyword}');
					`;
				}
				for (let subject of article.subjects) {
					query += `
					insert into source.subjects
					values (${id}, '${subject}');
					`;
				}
				for (let reference of article.references) {
					query += `
					insert into source."references" (id, journal, title)
					values (${id}, '${reference.journal}', '${reference.title}');
					`;
				}
				Article.dataSource.connector.execute(query, function(error, results) {
					if (error) {
						cb(error);
					} else {
						console.log(results);
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
					}
				});
			});
		}
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