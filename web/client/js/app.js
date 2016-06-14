var App = angular.module('app', [
	'ui.router',
	'ngCookies'
]);


App.config(['$stateProvider', '$urlRouterProvider', function($stateProvider, $urlRouterProvider) {
	$stateProvider
		.state('home', {
			url: '/home',
			templateUrl: 'templates/home.html',
			controller: 'HomeController'
		})
		.state('documents', {
			url: '/documents',
			templateUrl: 'templates/documents.html',
			controller: 'DocumentsController'
		});
	$urlRouterProvider.otherwise('home');
}]);