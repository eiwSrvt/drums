package;

import drums.BeatLines;
import drums.DrumSequencer;
import drums.Oscilliscope;
import drums.SequenceGrid;
import input.KeyCodes;
import js.Browser;
import js.html.*;
import js.html.audio.*;
import pixi.core.graphics.*;
import pixi.core.text.*;
import pixi.plugins.app.Application; // modified
import tones.*;
import tones.examples.*;
import util.*;


class Main extends Application {

	public static inline var displayWidth = 900;
	public static inline var displayHeight = 448;

	var graphics:Graphics;

	var audioContext:AudioContext;
	var outGain:GainNode;

	var drums:DrumSequencer;
	var oscilliscope:Oscilliscope;
	var sequenceGrid:SequenceGrid;
	var beatLines:BeatLines;
	var ready:Bool;

	public function new() {
		super();

		ready = false;

		initAudio();
		initPixi();

		//initOscilliscope();
		initBeatLines();
		initStepGrid();

		stageResized();

		Browser.window.addEventListener('keydown', function(e:KeyboardEvent) {
			switch(e.keyCode) {
				case KeyCodes.SPACE:
					if (drums.playing) drums.stop();
					else drums.play();
			}
		});
	}


	function initAudio() {
		audioContext = AudioBase.createContext();
		outGain = audioContext.createGain();
		outGain.gain.value = .2;
		outGain.connect(audioContext.destination);

		drums = new DrumSequencer(audioContext, outGain);
		drums.tick.connect(onSequenceTick);
		drums.ready.connect(onDrumsReady);
	}


	function onDrumsReady() {
		ready = true;
		drums.bpm = 60 + Math.random() * 80;
		drums.play(0);
	}


	function onSequenceTick(index:Int) {
		beatLines.tick(index);
		sequenceGrid.tick(index);

		var randomise = true;
		if (randomise) {
			if (index == 0 && Math.random() > .8) {
				drums.tracks[Std.int(Math.random() * 8)].randomise();
			}
			if (Math.random() > .95) {
				drums.tracks[Std.int(Math.random() * 8)].events[Std.int(Math.random() * 16)].active = Math.round(Math.random()) == 1;
			}
		}
	}


	function initPixi() {

		backgroundColor = 0x333333;
		antialias = true;
		onUpdate = tick;
		onResize = stageResized;

		start(Application.AUTO);

		// Ubuntu - 300,400,700
		var txt = new Text('drums', {font : '300 12px Ubuntu', fill : 'white', align : 'left'});
		stage.addChild(txt);
		txt.position.x = 10;
		txt.position.y = 10;
	}


	function initOscilliscope() {
		oscilliscope = new Oscilliscope(audioContext, 568, 120);
		stage.addChild(oscilliscope);
		drums.outGain.connect(oscilliscope.analyser);
	}


	function initBeatLines() {
		beatLines = new BeatLines(displayWidth, displayHeight);
		stage.addChild(beatLines);
	}


	function initStepGrid() {
		sequenceGrid = new SequenceGrid(drums);
		stage.addChild(sequenceGrid);
	}


	function tick(dt:Float) {
		if (!ready) return;
		//oscilliscope.update(dt);
		sequenceGrid.update(dt);
	}


	function stageResized() {
		var w2 = (width / 2);
		var h2 = (height / 2);// - 40;

		sequenceGrid.x = Math.round(w2 - beatLines.displayWidth / 2) + SequenceGrid.cellSize / 2;
		sequenceGrid.y = Math.round(h2 - sequenceGrid.displayHeight / 2) + SequenceGrid.cellSize / 2;

		beatLines.displayHeight = Math.round(height);
		beatLines.position.x = sequenceGrid.x;
		beatLines.position.y = 0;

		//oscilliscope.position.x = beatLines.position.x - 2;
		//oscilliscope.position.y = 160 + beatLines.position.y + beatLines.displayHeight/2;
	}


	static function main() {
		// start up once fonts have loaded
		WebFontEmbed.loaded = function() new Main();
		WebFontEmbed.load();
	}
}