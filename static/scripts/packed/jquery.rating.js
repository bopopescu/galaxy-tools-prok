if(window.jQuery){(function(a){if(a.browser.msie){try{document.execCommand("BackgroundImageCache",false,true)}catch(b){}}a.fn.rating=function(d){if(this.length==0){return this}if(typeof arguments[0]=="string"){if(this.length>1){var c=arguments;return this.each(function(){a.fn.rating.apply(a(this),c)})}a.fn.rating[arguments[0]].apply(this,a.makeArray(arguments).slice(1)||[]);return this}var d=a.extend({},a.fn.rating.options,d||{});a.fn.rating.calls++;this.not(".star-rating-applied").addClass("star-rating-applied").each(function(){var g,l=a(this);var e=(this.name||"unnamed-rating").replace(/\[|\]/g,"_").replace(/^\_+|\_+$/g,"");var f=a(this.form||document.body);var k=f.data("rating");if(!k||k.call!=a.fn.rating.calls){k={count:0,call:a.fn.rating.calls}}var n=k[e];if(n){g=n.data("rating")}if(n&&g){g.count++}else{g=a.extend({},d||{},(a.metadata?l.metadata():(a.meta?l.data():null))||{},{count:0,stars:[],inputs:[]});g.serial=k.count++;n=a('<span class="star-rating-control"/>');l.before(n);n.addClass("rating-to-be-drawn");if(l.attr("disabled")){g.readOnly=true}n.append(g.cancel=a('<div class="rating-cancel"><a title="'+g.cancel+'">'+g.cancelValue+"</a></div>").mouseover(function(){a(this).rating("drain");a(this).addClass("star-rating-hover")}).mouseout(function(){a(this).rating("draw");a(this).removeClass("star-rating-hover")}).click(function(){a(this).rating("select")}).data("rating",g))}var j=a('<div class="star-rating rater-'+g.serial+'"><a title="'+(this.title||this.value)+'">'+this.value+"</a></div>");n.append(j);if(this.id){j.attr("id",this.id)}if(this.className){j.addClass(this.className)}if(g.half){g.split=2}if(typeof g.split=="number"&&g.split>0){var i=(a.fn.width?j.width():0)||g.starWidth;var h=(g.count%g.split),m=Math.floor(i/g.split);j.width(m).find("a").css({"margin-left":"-"+(h*m)+"px"})}if(g.readOnly){j.addClass("star-rating-readonly")}else{j.addClass("star-rating-live").mouseover(function(){a(this).rating("fill");a(this).rating("focus")}).mouseout(function(){a(this).rating("draw");a(this).rating("blur")}).click(function(){a(this).rating("select")})}if(this.checked){g.current=j}l.hide();l.change(function(){a(this).rating("select")});j.data("rating.input",l.data("rating.star",j));g.stars[g.stars.length]=j[0];g.inputs[g.inputs.length]=l[0];g.rater=k[e]=n;g.context=f;l.data("rating",g);n.data("rating",g);j.data("rating",g);f.data("rating",k)});a(".rating-to-be-drawn").rating("draw").removeClass("rating-to-be-drawn");return this};a.extend(a.fn.rating,{calls:0,focus:function(){var d=this.data("rating");if(!d){return this}if(!d.focus){return this}var c=a(this).data("rating.input")||a(this.tagName=="INPUT"?this:null);if(d.focus){d.focus.apply(c[0],[c.val(),a("a",c.data("rating.star"))[0]])}},blur:function(){var d=this.data("rating");if(!d){return this}if(!d.blur){return this}var c=a(this).data("rating.input")||a(this.tagName=="INPUT"?this:null);if(d.blur){d.blur.apply(c[0],[c.val(),a("a",c.data("rating.star"))[0]])}},fill:function(){var c=this.data("rating");if(!c){return this}if(c.readOnly){return}this.rating("drain");this.prevAll().andSelf().filter(".rater-"+c.serial).addClass("star-rating-hover")},drain:function(){var c=this.data("rating");if(!c){return this}if(c.readOnly){return}c.rater.children().filter(".rater-"+c.serial).removeClass("star-rating-on").removeClass("star-rating-hover")},draw:function(){var c=this.data("rating");if(!c){return this}this.rating("drain");if(c.current){c.current.data("rating.input").attr("checked","checked");c.current.prevAll().andSelf().filter(".rater-"+c.serial).addClass("star-rating-on")}else{a(c.inputs).removeAttr("checked")}c.cancel[c.readOnly||c.required?"hide":"show"]();this.siblings()[c.readOnly?"addClass":"removeClass"]("star-rating-readonly")},select:function(d,f){var e=this.data("rating");if(!e){return this}if(e.readOnly){return}e.current=null;if(typeof d!="undefined"){if(typeof d=="number"){return a(e.stars[d]).rating("select",undefined,f)}if(typeof d=="string"){a.each(e.stars,function(){if(a(this).data("rating.input").val()==d){a(this).rating("select",undefined,f)}})}}else{e.current=this[0].tagName=="INPUT"?this.data("rating.star"):(this.is(".rater-"+e.serial)?this:null)}this.data("rating",e);this.rating("draw");var c=a(e.current?e.current.data("rating.input"):null);if((f||f==undefined)&&e.callback){e.callback.apply(c[0],[c.val(),a("a",e.current)[0]])}},readOnly:function(c,d){var e=this.data("rating");if(!e){return this}e.readOnly=c||c==undefined?true:false;if(d){a(e.inputs).attr("disabled","disabled")}else{a(e.inputs).removeAttr("disabled")}this.data("rating",e);this.rating("draw")},disable:function(){this.rating("readOnly",true,true)},enable:function(){this.rating("readOnly",false,false)}});a.fn.rating.options={cancel:"Cancel Rating",cancelValue:"",split:0,starWidth:16};a(function(){a("input[type=radio].star").rating()})})(jQuery)};