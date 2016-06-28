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
			let title = real_escape_string(article.title),
				journal = real_escape_string(article.journal) || '',
				year = real_escape_string(article.year) || null,
				doi = real_escape_string(article.doi) || '',
				query = `
				select greatest(900000, max(id))+1 as id from source.articles;
				select max(processid)+1 as process_id from source.articles`
			Article.dataSource.connector.execute(query, function(error, results) {
				if (error) {
					cb(error);
				} else {
                    cb(new Error(title));
					let id = results[0].id,
						process_id = results[1].process_id;
					query = `
						insert into source.articles
						values (${process_id}, ${id}, '${title}', '${journal}', null, '${doi}', ${year});
						`;
					for (let i in article.authors) {
						let author = real_escape_string(article.authors[i]);
						query += `
							insert into source.signatures 
							values (${id}, ${i}, '${author.first_name}', '${author.first_name.substr(0,1)}', '${author.middle_name.substr(0,1)}', '${author.last_name}', '${author.middle_name}');
							`;
					}
					for (let keyword of article.keywords) {
                        keyword_clean = real_escape_string(keyword)
						query += `
							insert into source.keywords
							values (${id}, 'WEB', '${keyword_clean}');
							`;
					}
					for (let subject of article.subjects) {
                        subject_clean = real_escape_string(subject)
						query += `
							insert into source.subjects
							values (${id}, '${subject_clean}');
							`;
					}
					for (let reference of article.references) {
                        ref_journal_clean = real_escape_string(reference.journal)
                        ref_title_clean = real_escape_string(reference.title)
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
    function real_escape_string (str) {
        return str.replace(/[\0\x08\x09\x1a\n\r"'\\\%]/g, function (char) {
            switch (char) {
                case "\0":
                    return "\\0";
                case "\x08":
                    return "\\b";
                case "\x09":
                    return "\\t";
                case "\x1a":
                    return "\\z";
                case "\n":
                    return "\\n";
                case "\r":
                    return "\\r";
                case "\"":
                case "'":
                case "\\":
                case "%":
                    return "\\"+char; // prepends a backslash to backslash, percent,
                                      // and double/single quotes
            }
        });
    }
};