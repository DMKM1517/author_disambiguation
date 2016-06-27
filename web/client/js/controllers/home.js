'use strict';

App.controller('HomeController', ['$scope', '$cookies', '$state', '$http', function($scope, $cookies, $state, $http) {
	var socket = io();
	const	prog_step = 100 / 14;
	$scope.logged_in = false;
	$scope.mendeley_opened = true;
	$scope.results_opened = false;
	$scope.processing = false;
	$scope.progress = 0;
	/*$scope.results = [[{"d1":0,"title":"Geographic and seasonal variability in the isotopic niche of little auks","author":"Welcker J"},{"d1":0,"title":"Long-term survival effect of corticosterone manipulation in Black-legged kittiwakes","author":"Welcker J"},{"d1":0,"title":"Chemical and mineralogical characterizations of LD converter steel slags: A multi-analytical techniques approach","author":"Waligora J"},{"d1":0,"title":"Current status of veterinary vaccines","author":"Walker J"},{"d1":0,"title":"Effects of the Selective Progesterone Receptor Modulator Asoprisnil on Uterine Artery Blood Flow, Ovarian Activity, and Clinical Symptoms in Patients with Uterine Leiomyomata Scheduled for Hysterectomy","author":"Walker J"},{"d1":0,"title":"A role of the (pro)renin receptor in neuronal cell differentiation","author":"Walker J"},{"d1":0,"title":"Impacts of experimentally increased foraging effort on the family: offspring sex matters","author":"Welcker J"},{"d1":0,"title":"How does corticosterone affect parental behaviour and reproductive success? A study of prolactin in black-legged kittiwakes","author":"Welcker J"},{"d1":0,"title":"Flexibility in the parental effort of an Arctic-breeding seabird","author":"Welcker J"},{"d1":0,"title":"Assessment Methods for Ammonia Hot-Spots","author":"Walker J"},{"d1":0,"title":"Trends in postpartum hemorrhage in high resource countries: a review and recommendations from the International Postpartum Hemorrhage Collaborative Group","author":"Walker J"},{"d1":0,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Walker J"},{"d1":0,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Walker J"},{"d1":0,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Walker J"},{"d1":0,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Walker J"},{"d1":0,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Walker J"},{"d1":0,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Walker J"},{"d1":0,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Walker J"},{"d1":0,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Walker J"}],[{"d1":1,"title":"REFERENCE INTERVALS FOR AMINOACIDS AND ORGANIC ACIDS OBTAINED BY UNSUPERVISED MULTIVARIATE ANALYSES","author":"Barouki R"},{"d1":1,"title":"Word Mapping and Executive Functioning in Young Monolingual and Bilingual Children","author":"Barac R"},{"d1":1,"title":"ATF4 AND THE INTEGRATED STRESS RESPONSE ARE INDUCED BY ETHANOL AND CYTOCHROME P450 2E1 IN HUMAN HEPATOCYTES","author":"Barouki R"},{"d1":1,"title":"Experiences of VoIP traffic monitoring in a commercial ISP","author":"Birke R"},{"d1":1,"title":"Linking long-term toxicity of xeno-chemicals with short-term biological adaptation","author":"Barouki R"},{"d1":1,"title":"Winding Roads: Routing edges into bundles","author":"Bourqui R"},{"d1":1,"title":"Persistent Induction of Cytochrome P4501A1 in Human Hepatoma Cells by 3-Methylcholanthrene: Evidence for Sustained Transcriptional Activation of the CYP1A1 Promoter","author":"Barouki R"},{"d1":1,"title":"EFFECT OF QUERCETIN ON PARAOXONASE 1 ACTIVITY - STUDIES IN CULTURED CELLS, MICE AND HUMANS","author":"Barouki R"},{"d1":1,"title":"Adapting cyclosporine to calcineurin activity rather than to cyclosporine blood levels: Toward a functional management of graft-versus-host disease prophylaxis","author":"Barouki R"},{"d1":1,"title":"Rapid micro array-based method for monitoring of all currently known single-nucleotide polymorphisms associated with parasite resistance to antimalaria drugs","author":"Burki R"},{"d1":1,"title":"Stabilization of IGFBP-1 mRNA by ethanol in hepatoma cells involves the JNK pathway","author":"Barouki R"},{"d1":1,"title":"Predicting weather regime transitions in Northern Hemisphere datasets","author":"Berk R"},{"d1":1,"title":"Cytosolic aspartate aminotransferase, a new partner in adipocyte glyceroneogenesis and an atypical target of thiazolidinedione","author":"Barouki R"},{"d1":1,"title":"The aryl hydrocarbon receptor, more than a xenobiotic-interacting protein","author":"Barouki R"},{"d1":1,"title":"Cellular stress","author":"Barouki R"},{"d1":1,"title":"Metabolic network visualization eliminating node redundance and preserving metabolic pathways","author":"Bourqui R"},{"d1":1,"title":"Criteria for choosing clinically effective glaucoma treatment: A discussion panel consensus","author":"Burk R"},{"d1":1,"title":"Hypoxia and estrogen co-operate to regulate gene expression in T-47D human breast cancer cells","author":"Barouki R"},{"d1":1,"title":"Weather regime prediction using statistical learning","author":"Berk R"},{"d1":1,"title":"Transcriptome based prediction of the response to neoadjuvant chemotherapy of head and neck squamous cell carcinoma","author":"Barouki R"},{"d1":1,"title":"How to draw clustered weighted graphs using a multilevel force-directed graph drawing algorithm","author":"Bourqui R"},{"d1":1,"title":"Surgical interventions with FEIBA (SURF) - studying the feasibility of surgery in inhibitor patients","author":"Berg R"},{"d1":1,"title":"Automated diagnosis for UMTS networks using Bayesian network approach","author":"Barco R"},{"d1":1,"title":"Cytochrome P450 2E1 and alcohol induce ATF4 and the integrated stress response in hepatocytes","author":"Barouki R"},{"d1":1,"title":"Hypoxia down-regulates CCAAT/Enhancer binding protein-alpha expression in breast cancer cells","author":"Barouki R"},{"d1":1,"title":"Control of cellular physiology by TM9 proteins in yeast and Dictyostelium","author":"Birke R"},{"d1":1,"title":"Toward a functional management of graft-versus-host disease prophylaxis by adapting cyclosporin doses to calcineurin activity rather than to cyclosporin blood levels","author":"Barouki R"},{"d1":1,"title":"PFAPA (Periodic fever, aphtous stomatitis, pharyngitis and cervical adenitis) Syndrome registry: analysis of a cohort of 214 patients","author":"Brik R"},{"d1":1,"title":"Expression of inosine monophosphate dehydrogenase type I and type II after mycophenolate mofetil treatment: A 2-year follow-up in kidney transplantation","author":"Barouki R"},{"d1":1,"title":"Revealing subnetwork roles using contextual visualization: Comparison of metabolic networks","author":"Bourqui R"},{"d1":1,"title":"Essential oils can substitute growth promoter antibiotics in broiler chicken","author":"Bergaoui R"},{"d1":1,"title":"Characterisation of a human liver cystathionine beta synthase mRNA sequence corresponding to the c.[833T > C;844_845ins68] mutation in CBS gene","author":"Barouki R"},{"d1":1,"title":"The aryl hydrocarbon receptor and cellular plasticity","author":"Barouki R"},{"d1":1,"title":"Role of Paris PM2.5 components in the pro-inflammatory response induced in airway epithelial cells","author":"Barouki R"},{"d1":1,"title":"NKT Cell-Plasmacytoid Dendritic Cell Cooperation via OX40 Controls Viral Infection in a Tissue-Specific Manner","author":"Barouki R"},{"d1":1,"title":"Role of environmental pollutants in adipose tisssue inflammation in obese patients","author":"Barouki R"},{"d1":1,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Borgo R"},{"d1":1,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Borgo R"},{"d1":1,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Borgo R"},{"d1":1,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Borgo R"},{"d1":1,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Borgo R"},{"d1":1,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Borgo R"},{"d1":1,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Borgo R"},{"d1":1,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Borgo R"}],[{"d1":2,"title":"Efficacy and tolerability of naratriptan for short-term prevention of menstrually related migraine: Data from two randomized, double-blind, placebo-controlled studies","author":"Jones MW"},{"d1":2,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Jones MW"},{"d1":2,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Jones MW"},{"d1":2,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Jones MW"},{"d1":2,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Jones MW"},{"d1":2,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Jones MW"},{"d1":2,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Jones MW"},{"d1":2,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Jones MW"},{"d1":2,"title":"TimeNotes: A Study on Effective Chart Visualization and Interaction Techniques for Time-Series Data","author":"Jones MW"}]];*/
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
	$http.get('/getSubjects').then(function(resp) {
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
	});

	if ($cookies.get('accessToken')) {
		$scope.logged_in = true;
		MendeleySDK.API.setAuthFlow(MendeleySDK.Auth.authCodeFlow({
			apiAuthenticateUrl: '/login',
			refreshAccessTokenUrl: '/oauth/refresh'
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
		if (doc.identifiers && doc.identifiers.doi) {
			$scope.article.doi = doc.identifiers.doi;
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
		$scope.processing = true;
		$scope.progress = 0;
		$scope.processing_authors = $scope.article.authors;
		$('#submit').text('Processing...');
		$('#submit').prop('disabled', true);
		$http.post('/api/Articles/disambiguate', {
			article: $scope.article
		}).then(function(resp) {
				if (resp.data && resp.data.process_id) {
					let process_id = resp.data.process_id;
					console.log(process_id);
					$scope.progress += prog_step;
					$scope.mendeley_opened = false;
					$scope.results_opened = true;
					socket.emit('process', process_id);
				} else {
					console.log('error');
					$('#submit').text('Submit');
					$('#submit').prop('disabled', false);
				}
			},
			function(err) {
				console.error(err);
				let msg = 'An error occurred. Try again.';
				if (err.data && err.data.error && err.data.error.message) {
					msg = err.data.error.message;
				}
				alert(msg);
				$('#submit').text('Submit');
				$('#submit').prop('disabled', false);
			});
	};

	$scope.reset = function(event) {
		event.preventDefault();
		$scope.article = {
			authors: [],
			references: []
		};
		$('.document').removeClass('active');
	};

	$scope.cancel = function() {
		socket.emit('cancel_process');
		$('#submit').text('Submit');
		$('#submit').prop('disabled', false);
	};

	socket.on('output', function(msg) {
		console.log(msg);
		$scope.progress += prog_step;
		$scope.$apply();
	});
	socket.on('results', function(results) {
		// console.log(results);
		$scope.processing = false;
		let disambiguated = JSON.parse(results);
		$scope.results = disambiguated;
		$scope.$apply();
		$('#submit').text('Submit');
		$('#submit').prop('disabled', false);
	});
	socket.on('err', function() {
		$scope.processing = false;
		$scope.results = {};
		$scope.results_opened = false;
		$scope.$apply();
		alert('An error occurred. Try again.');
		$('#submit').text('Submit');
		$('#submit').prop('disabled', false);
	});

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