var LiveSearch={searchBoxes:"",activeRequests:[],callbacks:[],addCallback:function(e,r){return void 0===this.callbacks[e]&&(this.callbacks[e]=[]),this.callbacks[e].push(r)},invokeCallbacks:function(e,r){var s;if(void 0!==this.callbacks[e])for(s in this.callbacks[e])r=this.callbacks[e][s](r)},init:function(){LiveSearch.searchBoxes=jQuery("input").filter("[name='s']").not(".no-livesearch"),LiveSearch.searchBoxes.keyup(LiveSearch.handleKeypress),LiveSearch.searchBoxes.focus(LiveSearch.hideResults),LiveSearch.searchBoxes.outerHeight||alert(DavesWordPressLiveSearchConfig.outdatedJQuery),LiveSearch.searchBoxes.parents("form").attr("autocomplete","off"),LiveSearch.searchBoxes.each(function(){this.autocomplete="off"}),jQuery("html").click(LiveSearch.hideResults),LiveSearch.searchBoxes.click(function(e){e.stopPropagation()}),LiveSearch.compiledResultTemplate=_.template(DavesWordPressLiveSearchConfig.resultTemplate),jQuery(window).resize(function(){LiveSearch.positionResults(this)})},positionResults:function(){var e,r=jQuery("input:focus").first(),s=jQuery("#dwls_search_results");if(s&&r.size()>0){var a=r.offset();switch(a.left+=parseInt(DavesWordPressLiveSearchConfig.xOffset,10),a.top+=parseInt(DavesWordPressLiveSearchConfig.yOffset,10),s.css("left",a.left),s.css("top",a.top),s.css("display","block"),DavesWordPressLiveSearchConfig.resultsDirection){case"up":e=a.top-s.height();break;case"down":e=a.top+LiveSearch.searchBoxes.outerHeight();break;default:e=a.top+LiveSearch.searchBoxes.outerHeight()}s.css("top",e+"px")}},handleAJAXResults:function(e){var r="";if(LiveSearch.activeRequests.pop(),e){if(resultsSearchTerm=e.searchTerms,resultsSearchTerm!=jQuery("input:focus").first().val())return void(0===LiveSearch.activeRequests.length&&LiveSearch.removeIndicator());var s=jQuery("#dwls_search_results").children("input[name=query]").val();if(""!==s&&resultsSearchTerm==s)return void(0===LiveSearch.activeRequests.length&&LiveSearch.removeIndicator());if(0===e.results.length)LiveSearch.hideResults(),LiveSearch.invokeCallbacks("ZeroResults");else LiveSearch.invokeCallbacks("BeforeDisplayResults"),r=LiveSearch.compiledResultTemplate({searchResults:e.results,e:e,resultsSearchTerm:resultsSearchTerm}),jQuery("#dwls_search_results").size()>0?jQuery("#dwls_search_results").replaceWith(r):jQuery("body").append(r),LiveSearch.positionResults(),jQuery("#dwls_search_results li").bind("click.dwls",function(e){window.location.href=jQuery(this).find("a.daves-wordpress-live-search_title").attr("href")}),LiveSearch.invokeCallbacks("AfterDisplayResults");0===LiveSearch.activeRequests.length&&LiveSearch.removeIndicator()}},handleKeypress:function(e){var r=LiveSearch.searchBoxes.val();setTimeout(function(){LiveSearch.runQuery(r)},0)},runQuery:function(e){var r,s,a=jQuery("input:focus"),i=a.val();if(""===i||i.length<DavesWordPressLiveSearchConfig.minCharsToSearch)LiveSearch.hideResults(),LiveSearch.removeIndicator();else{for(LiveSearch.displayIndicator();LiveSearch.activeRequests.length>0;)(s=LiveSearch.activeRequests.pop()).abort();var t={},c=a.parents("form").find("input:not(:submit),select,textarea");for(r in c)if(c.hasOwnProperty(r)&&r%1==0){var o=jQuery(c[r]);t[o.attr("name")]=o.val()}t.action="dwls_search",(s=jQuery.get(DavesWordPressLiveSearchConfig.ajaxURL,t,LiveSearch.handleAJAXResults,"json")).fail=LiveSearch.ajaxFailHandler,LiveSearch.activeRequests.push(s)}},ajaxFailHandler:function(e){console.log("Dave's WordPress Live Search: There was an error retrieving or parsing search results"),console.log("The data returned was:"),console.log(e)},hideResults:function(){var e=jQuery("#dwls_search_results");if(e.size()>0)switch(LiveSearch.invokeCallbacks("BeforeHideResults"),DavesWordPressLiveSearchConfig.resultsDirection){case"up":e.fadeOut("normal",function(){e.remove(),LiveSearch.invokeCallbacks("AfterHideResults")});break;case"down":e.slideUp("normal",function(){e.remove(),LiveSearch.invokeCallbacks("AfterHideResults")});break;default:e.slideUp("normal",function(){e.remove(),LiveSearch.invokeCallbacks("AfterHideResults")})}},displayIndicator:function(){if(0===jQuery(".search_results_activity_indicator").size()){var e=jQuery("input:focus").first(),r=e.offset();jQuery("body").append('<span id="search_results_activity_indicator" class="search_results_activity_indicator" />');var s={outer:Math.ceil(.9*e.height()/2)};s.inner=Math.floor(.29*s.outer),jQuery(".search_results_activity_indicator").css("position","absolute").css("z-index",9999);var a=r.top+(e.outerHeight()-e.innerHeight())/2+"px";jQuery(".search_results_activity_indicator").css("top",a);var i=r.left+e.outerWidth()-2*(s.outer+s.inner)-2+"px";jQuery(".search_results_activity_indicator").css("left",i),LiveSearch.invokeCallbacks("BeforeDisplaySpinner"),Spinners.create(".search_results_activity_indicator",{radii:[s.inner,s.outer],color:"#888888",dashWidth:4,dashes:8,opacity:.8,speed:.7}).play(),LiveSearch.invokeCallbacks("AfterDisplaySpinner")}},removeIndicator:function(){LiveSearch.invokeCallbacks("BeforeHideSpinner"),jQuery(".search_results_activity_indicator").remove(),LiveSearch.invokeCallbacks("AfterHideSpinner")}};jQuery(function(){LiveSearch.init()});