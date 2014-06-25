var system = require('system');
var args = system.args;

var req_page = require('webpage');

var LOAD_PAGES = parseInt(args[1]);
var NAV_PAGES = parseInt(args[2]);

var pagesLoaded = 0;

function loadOnePage() {
	var page = req_page.create();

	page.open('http://localhost:5505/?src=matrix&ck=web1', function (status) {
		page.clearCookies();
		page.close();
		
		pagesLoaded += 1;
		// console.log("Page done: " + pagesLoaded);
		
		if (pagesLoaded < LOAD_PAGES) {
			loadOnePage();
		} else {
			var resultPage = req_page.create();
			
			resultPage.open('http://localhost:5505/test_results/?should_users_count=' + LOAD_PAGES + '&should_events_count=' + LOAD_PAGES, function (status) {
			  console.log(resultPage.content);
			  phantom.exit();
			});			
		}
	});
}

function loadTwoPages() {
	var page = req_page.create();

	page.open('http://localhost:5505/?src=matrix&ck=web1', function (status) {

		page.open('http://localhost:5505/signup', function (status) {
			pagesLoaded += 1;
			// console.log("Page done: " + pagesLoaded);

			page.clearCookies();
			page.close();
			
			if (pagesLoaded < LOAD_PAGES) {
				loadTwoPages();
			} else {
				var resultPage = req_page.create();
			
				resultPage.open('http://localhost:5505/test_results/?should_users_count=' + LOAD_PAGES + '&should_events_count=' + (LOAD_PAGES*2), function (status) {
				  console.log(resultPage.content);
				  phantom.exit();
				});			
			}
			
		});
		
	});
}

if (NAV_PAGES == 1) {
	loadOnePage();
} else {
	loadTwoPages();
}
