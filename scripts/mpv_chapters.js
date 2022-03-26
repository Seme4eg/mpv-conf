"use strict";

//display chapter on osd and easily switch between chapters by click on title of chapter
mp.register_event("file-loaded", init);
mp.observe_property("chapter", "number", onChapterChange);
mp.observe_property("chapter-list/count", "number", init);

var options = {
  font_size: 16,
  font_color: "FFFFFF",
  border_size: 1.0,
  border_color: "000000",
  font_color_currentChapter: "C27F1B",
};

var playinfo = {
  chapters: [], //array
  chaptercount: "", // int
  assinterface: [], //array(deprecated, use single assdraw instead)
  currentChapter: "", //int
  loaded: false,
};

var toggle_switch = false;
var assdraw = mp.create_osd_overlay("ass-events");
var autohidedelay = mp.get_property_number("cursor-autohide");

function init() {
  playinfo.chapters = getChapters();
  playinfo.chaptercount = playinfo.chapters.length;
  if (playinfo.chaptercount == 0) return;

  while (playinfo.chaptercount * options.font_size > 1000 / 1.5)
    options.font_size = options.font_size - 1;

  drawChapterList();
  mp.msg.info("initiated");
  playinfo.loaded = true;
}

function getChapters() {
  var chapterCount = mp.get_property("chapter-list/count");
  if (chapterCount === 0) return ["null"];
  else {
    var chaptersArray = [];
    for (var index = 0; index < chapterCount; index++) {
      var chapterTitle = mp.get_property_native(
        "chapter-list/" + index + "/title"
      );

      if (chapterTitle != undefined) chaptersArray.push(chapterTitle);

    }
    return chaptersArray;
  }
}

function drawChapterList() {
  var resY = 0;
  var resX = 0;
  var assdrawdata = "";

  function setFontColor(str, index) {
    var _color = playinfo.currentChapter == index ? options.font_color_currentChapter :
 options.font_color;
    return str + "{\\c&H" + _color + "&}";
  }

  function setEndofLine(str) {
    str = str + "\n";
    return str;
  }
  playinfo.chapters.forEach(function (element, index) {
    assdrawdata = "{\\pos(" + resX + ", " + resY + ")}" // position
      + "{\\bord" + options.border_size + "}" // border size
      + "{\\3c&H" + options.border_color + "&}" // border color
      + setFontColor(assdrawdata, index)
      + "{\\fs" + options.font_size + "}" // font
      + "{\\p0}" // end of modifiers
      + element + "\n"

    resY += options.font_size;
  });
  assdraw.data = assdrawdata;
}

function toggleOverlay() {
  if (!playinfo.loaded) {
    return;
  }
  if (!toggle_switch) {
    drawChapterList();
    assdraw.update();
    mp.set_property("cursor-autohide", "no");
    toggle_switch = !toggle_switch;
  } else {
    assdraw.remove();
    mp.set_property("cursor-autohide", autohidedelay);
    toggle_switch = !toggle_switch;
  }
}

function onChapterChange() {
  playinfo.currentChapter = mp.get_property_native("chapter");
  if (playinfo.currentChapter != undefined) {
    drawChapterList();
  }

  if ((playinfo.currentChapter != undefined) & toggle_switch) {
    assdraw.update();
  }
}
function pos2chapter(x, y, overallscale) {
  var vectical = y / (options.font_size * overallscale);
  if (vectical > playinfo.chaptercount) {
    return null;
  }
  var intVectical = Math.floor(vectical);
  var lengthofTitleClicked = playinfo.chapters[intVectical].length;
  var lengthofTitleClicked_px =
    (lengthofTitleClicked * options.font_size) / overallscale;
  if (x < lengthofTitleClicked_px) {
    return intVectical;
  } else {
    return null;
  }
}
function getOverallScale() {
  return mp.get_osd_size().height / 720;
}
function onMBTN_LEFT() {
  //get mouse position
  if (!playinfo.loaded) {
    return;
  }
  if (toggle_switch) {
    var overallscale = getOverallScale();
    var pos = mp.get_mouse_pos();
    var chapterClicked = pos2chapter(pos.x, pos.y, overallscale);
    if (chapterClicked != null) {
      mp.set_property_native("chapter", chapterClicked);
    }
  }
}
mp.add_key_binding("ctrl+/", function () {
  toggleOverlay();
});
mp.add_key_binding("MBTN_LEFT", "mbtn_left", function () {
  onMBTN_LEFT();
});
