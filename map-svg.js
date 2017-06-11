// utility functions
d3.selection.prototype.moveToFront = function () {
  return this.each(function () {
    this.parentNode.appendChild(this);
  });
};

String.prototype.capitalize = function() {
    return this.replace(/(?:^|\s)\S/g, function(a) { return a.toUpperCase(); });
};

// drop shadow filter
var svg = d3.select("svg");
var defs = svg.append("defs");
var filter = defs.append("filter")
    .attr("id", "dropshadow");
filter.append("feGaussianBlur")
    .attr("in", "SourceAlpha")
    .attr("stdDeviation", .25)
    .attr("result", "blur");
filter.append("feOffset")
    .attr("in", "blur")
    .attr("dx", 8)
    .attr("dy", -8)
    .attr("result", "offsetBlur");
filter.append("feFlood")
      .attr("in", "offsetBlur")
      .attr("flood-color", "#222")
      .attr("flood-opacity", "0.5")
      .attr("result", "offsetColor");
filter.append("feComposite")
      .attr("in", "offsetColor")
      .attr("in2", "offsetBlur")
      .attr("operator", "in")
      .attr("result", "offsetBlur");
var feMerge = filter.append("feMerge");
feMerge.append("feMergeNode")
    .attr("in", "offsetBlur");
feMerge.append("feMergeNode")
    .attr("in", "SourceGraphic");



// proper setup time
var dataToBind = d3.entries(dataset.map(function(d,i) {return d[0]}));
var districtPolys = d3.select(".polygon").selectAll("polygon");
districtPolys.data(dataToBind);

var getColor = function(x) {
  if(x == "NA") {
  	return na_color;
  }
  else {
  	var index = Math.round(x * 1000) + 1;
  	return colorkey[index];
  }
}

var active = "bicycle";
change = function(key) {
  active = key;
  d3.selectAll(".item_option").attr("stroke","gray").attr("fill","gray");
  d3.select("#"+key).attr("stroke","crimson").attr("fill","crimson");
  d3.select(".polygon").selectAll("polygon").transition().attr("fill", function(d){ return getColor(d.value[key+".prop"])});
};




// mouseover popup
districtPolys.on("mouseover", function(d) {
  //Create the tooltip label
  var tooltip = d3.select(this.parentNode).append("g");
  tooltip
  .attr("id","tooltip")
  .attr("transform","translate(40,40)")
  .append("rect")
  .attr("stroke","white")
  .attr("stroke-opacity",0.5)
  .attr("fill","white")
  .attr("fill-opacity",0.5)
  .attr("height",90)
  .attr("width",270)
  .attr("rx",5)
  .attr("x",0)
  .attr("y",0);
  tooltip.append("text")
  .attr("transform","scale(1,-1)")
  .attr("x",3)
  .attr("y",-60)
  .attr("text-anchor","start")
  .attr("stroke","gray")
  .attr("fill","gray")
  .attr("fill-opacity",1)
  .attr("opacity",1)
  .attr("font-size",24)
  .text("district: " + d.value.district.capitalize());
  tooltip.append("text")
  .attr("transform","scale(1,-1)")
  .attr("x",3)
  .attr("y",-34)
  .attr("text-anchor","start")
  .attr("stroke","gray")
  .attr("fill","gray")      
  .attr("fill-opacity",1)
  .attr("opacity",1)
  .attr("font-size",24)
  .text("ownership rate: " + (!isNaN(d.value[active+".prop"]) ? Math.round(d.value[active+".prop"]*100) + "%" : "-"));
  tooltip.append("text")
  .attr("transform","scale(1,-1)")
  .attr("x",3)
  .attr("y",-8)
  .attr("text-anchor","start")
  .attr("stroke","gray")
  .attr("fill","gray")
  .attr("fill-opacity",1)
  .attr("opacity",1)
  .attr("font-size",16)
  .text("95% confidence: "+(!isNaN(d.value[active+".conf_lower"]) ? Math.round(d.value[active+".conf_lower"]*100) + "%" : "-")+" to "+(!isNaN(d.value[active+".conf_upper"]) ? Math.round(d.value[active+".conf_upper"]*100) + "%" : "-"))
  
  d3.select(this).moveToFront()
    .attr("filter", "url(#dropshadow)")
    .attr("stroke-opacity", 1);
}).on("mouseout", function(d) {       
  d3.select("#tooltip").remove();
  d3.select(this).moveToFront()
    .attr("filter", null)
    .attr("stroke-opacity", 0);
});



var legend = d3.select("#gridSVG").append("g");
legend
  .attr("id","legend")
  .attr("transform","translate(720,240)")
  .append("rect")
  .attr("stroke","black")
  .attr("stroke-opacity",0.5)
  .attr("fill","white")
  .attr("fill-opacity",0.5)
  .attr("height",230)
  .attr("width",200)
  .attr("rx",5)
  .attr("x",0)
  .attr("y",0);
legend.append("text").text("Household items")
  .attr("id","legend_head")
  .attr("y",-210)
  .attr("text-decoration","underline")
  
  
  
  
legend.append("text").text("bicycle")
  .attr("id","bicycle")
  .attr("y",-190)
  .on("mousedown", function(d) {change("bicycle")});
legend.append("text").text("motorcycle")
  .attr("id","motorcycle")
  .attr("y",-170)
  .on("mousedown", function(d) {change("motorcycle")});
legend.append("text").text("car")
  .attr("id","cars")
  .attr("y",-150)
  .on("mousedown", function(d) {change("car")});
legend.append("text").text("refrigerator")
  .attr("id","refrigerator")
  .attr("y",-130)
  .on("mousedown", function(d) {change("refrigerator")});
legend.append("text").text("television")
  .attr("id","television")
  .attr("y",-110)
  .on("mousedown", function(d) {change("television")});
legend.append("text").text("computer")
  .attr("id","computer")
  .attr("y",-90)
  .on("mousedown", function(d) {change("computer")});
legend.append("text").text("landline")
  .attr("id","telephone")
  .attr("y",-70)
  .on("mousedown", function(d) {change("telephone")});
legend.append("text").text("mobile phone")
  .attr("id","mobile")
  .attr("y",-50)
  .on("mousedown", function(d) {change("mobile")});
legend.append("text").text("cable tv")
  .attr("id","cable")
  .attr("y",-30)
  .on("mousedown", function(d) {change("cable")});
legend.append("text").text("internet access")
  .attr("id","internet")
  .attr("y",-10)
  .on("mousedown", function(d) {change("internet")});
  
d3.selectAll("#legend > text")
  .attr("font-size", "12px")
  .attr("class","item_option")
  .attr("opacity",1)
  .attr("stroke","gray")
  .attr("fill","gray")
  .attr("fill-opacity",1)
  .attr("cursor","pointer")
  .attr("transform","scale(1,-1)")
  .attr("x",10)

d3.select("#legend_head")
  .attr("font-size", "16px")
  .attr("class","")
  .attr("stroke","black")
  .attr("fill","black")
  .attr("cursor","default")

d3.selectAll("#bicycle")
  .attr("stroke","crimson")
  .attr("fill","crimson")

