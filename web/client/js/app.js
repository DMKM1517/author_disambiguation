var App = angular.module('app', [
	'ui.router',
	'ngCookies',
	'selectize'
]);


App.config(['$stateProvider', '$urlRouterProvider', function($stateProvider, $urlRouterProvider) {
	$stateProvider
		.state('/', {
			url: '/',
			templateUrl: 'templates/home.html',
			controller: 'HomeController'
		});
	$urlRouterProvider.otherwise('/');
}]);