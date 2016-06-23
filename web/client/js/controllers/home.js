'use strict';

App.controller('HomeController', ['$scope', '$cookies', '$state', '$http', function($scope, $cookies, $state, $http) {
	$scope.logged_in = false;
	$scope.mendeley_opened = true;
	$scope.results_opened = false;
	$scope.article = {
		authors: [],
		references: []
	};
	$scope.options_selectize = [];
	$scope.config_selectize = {
		create: true,
		createOnBlur: true,
		hideSelected: true,
		selectOnTab: true,
		plugins: ['remove_button']
	};
	$scope.options_selectize2 = [];
	$scope.config_selectize2 = {
		create: false,
		hideSelected: true,
		selectOnTab: true,
		closeAfterSelect: true,
		plugins: ['remove_button']
	};
	/*$http.get('/getSubjects').then(function(resp) {
		if (resp.data) {
			$scope.options_selectize2 = resp.data.map(x => {
				return {
					value: x.subject,
					text: x.subject
				}
			});
		}
	}, function(error) {
		console.error(error);
	});*/

	if ($cookies.get('accessToken')) {
		$scope.logged_in = true;
		MendeleySDK.API.setAuthFlow(MendeleySDK.Auth.authCodeFlow({
			apiAuthenticateUrl: '/login',
			// refreshAccessTokenUrl: '/oauth/refresh'
		}));
		MendeleySDK.API.profiles.me().done(function(profile) {
			$scope.name = profile.display_name;
			$scope.$apply();
		});
		MendeleySDK.API.documents.list().done(function(docs) {
			$scope.documents = docs;
			console.log(docs);
			$scope.$apply();
		}).fail(function(request, response) {
			console.log('Failed!');
			console.log('URL:', request.url);
			console.log('Status:', response.status);
		});
	}

	$scope.selectDocument = function(key) {
		$scope.article = {
			authors: [],
			references: []
		};
		let doc = $scope.documents[key];
		$scope.article.title = doc.title;
		$scope.article.authors = doc.authors.map(x => {
			let first_names = x.first_name.split(' ');
			let first_name = first_names[0].endsWith('.') ? first_names[0].slice(0, -1) : first_names[0];
			let middle_name = '';
			if (first_names[1]) {
				middle_name = first_names[1].endsWith('.') ? first_names[1].slice(0, -1) : first_names[1];
			}
			return {
				last_name: x.last_name,
				first_name: first_name,
				middle_name: middle_name
			}
		});
		if (doc.source) {
			$scope.article.journal = doc.source;
		}
		if (doc.year) {
			$scope.article.year = doc.year;
		}
		if (doc.keywords) {
			$scope.options_selectize = doc.keywords.map(x => {
				return {
					value: x,
					text: x
				}
			});
			$scope.article.keywords = doc.keywords;
		} else {
			$scope.options_selectize = [];
			$scope.article.keywords = [];
		}
		$('.document').removeClass('active');
		$('#d' + key).addClass('active');
	};

	$scope.addAuthor = function(event) {
		event.preventDefault();
		if ($scope.lastname && $scope.firstname && $scope.lastname.length > 1 && $scope.firstname.length > 0) {
			$scope.article.authors.push({
				last_name: $scope.lastname,
				first_name: $scope.firstname,
				middle_name: $scope.middlename
			});
			$scope.lastname = '';
			$scope.firstname = '';
			$scope.middlename = '';
		}
	};

	$scope.removeAuthor = function(key) {
		$scope.article.authors.splice(key, 1);
	};

	$scope.addReference = function(event) {
		event.preventDefault();
		if ($scope.title_reference && $scope.journal_reference && $scope.title_reference.length > 1 && $scope.journal_reference.length > 1) {
			$scope.article.references.push({
				title: $scope.title_reference,
				journal: $scope.journal_reference
			});
			$scope.title_reference = '';
			$scope.journal_reference = '';
		}
	};

	$scope.removeReference = function(key) {
		$scope.article.references.splice(key, 1);
	};

	$scope.submit = function(event) {
		event.preventDefault();
		let btn = $(event.target);
		btn.prop('disabled', true);
		$http.post('/api/Articles/disambiguate', {
			article: $scope.article
		}).then(function(resp) {
			if (resp.data && resp.data.authors) {
				let disambiguated = resp.data.authors;
				console.log(disambiguated);
				$scope.results_opened = true;
				$scope.results = disambiguated;
			}
			btn.prop('disabled', false);
		}, function(err) {
			console.error(err.data.error.message);
			btn.prop('disabled', false);
		});
	};

	/*$scope.loadFile = function(event) {
		var input = event.target;
		console.log(input.files[0]);
		var reader = new FileReader();
		reader.onload = function() {
			var dataURL = reader.result;
			console.log(dataURL);
		}
		reader.readAsDataURL(input.files[0])
	}*/
}]);