'use strict';

App.controller('HomeController', ['$scope', '$cookies', '$state', function($scope, $cookies, $state) {
	$scope.logged_in = false;
	$scope.article = {
		authors: []
	};
	$scope.options_selectize = [];
	$scope.config_selectize = {
		create: true,
		createOnBlur: true,
		hideSelected: true,
		selectOnTab: true,
		plugins: ['remove_button']
	};

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
		let doc = $scope.documents[key];
		$scope.article.title = doc.title;
		$scope.article.authors = doc.authors.map(x => {
			return {
				last_name: x.last_name,
				first_name: x.first_name,
			}
		});
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
		if ($scope.lastname.length > 1 && $scope.firstname.length > 0) {
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

	$scope.submit = function(event) {
		event.preventDefault();
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