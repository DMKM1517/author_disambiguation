'use strict';

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
			let title = _escapeString(article.title),
				journal = _escapeString(article.journal) || '',
				year = article.year || null,
				doi = _escapeString(article.doi) || '',
				query = `
				select greatest(900000, max(id))+1 as id from source.articles;
				select max(processid)+1 as process_id from source.articles`
			Article.dataSource.connector.execute(query, function(error, results) {
				if (error) {
					cb(error);
				} else {
					let id = results[0].id,
						process_id = results[1].process_id;
					query = `
						insert into source.articles
						values (${process_id}, ${id}, '${title}', '${journal}', null, '${doi}', ${year});
						`;
					for (let i in article.authors) {
						let author = article.authors[i],
							first_name = _escapeString(author.first_name),
							middle_name = _escapeString(author.middle_name),
							last_name = _escapeString(author.last_name);
						query += `
							insert into source.signatures 
							values (${id}, ${i}, '${first_name}', '${first_name.substr(0,1)}', '${middle_name.substr(0,1)}', '${last_name}', '${middle_name}');
							`;
					}
					for (let keyword of article.keywords) {
						let keyword_clean = _escapeString(keyword);
						query += `
							insert into source.keywords
							values (${id}, 'WEB', '${keyword_clean}');
							`;
					}
					for (let subject of article.subjects) {
						let subject_clean = _escapeString(subject);
						query += `
							insert into source.subjects
							values (${id}, '${subject_clean}');
							`;
					}
					for (let reference of article.references) {
						let ref_journal_clean = _escapeString(reference.journal);
						let ref_title_clean = _escapeString(reference.title);
						query += `
							insert into source."references" (id, journal, title)
							values (${id}, '${ref_journal_clean}', '${ref_title_clean}');
							`;
					}
					Article.dataSource.connector.execute(query, function(error, inserts) {
						if (error) {
							cb(error);
						} else {
							cb(null, process_id);
						}
					});
				}
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
			arg: 'process_id',
			type: 'number'
		}
	});
	var _escapeString = function(val) {
		val = val.replace(/[\0\n\r\b\t\\'"\x1a]/g, function(s) {
			switch (s) {
				case "\0":
					return "\\0";
				case "\n":
					return "\\n";
				case "\r":
					return "\\r";
				case "\b":
					return "\\b";
				case "\t":
					return "\\t";
				case "\x1a":
					return "\\Z";
				case "'":
					return "''";
				case '"':
					return '""';
				default:
					return "\\" + s;
			}
		});

		return val;
	};
};
