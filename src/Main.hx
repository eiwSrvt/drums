package;

import drums.ui.BeatLines;
import drums.DrumSequencer;
import drums.Oscilliscope;
import drums.ui.Controls;
import drums.ui.SequenceGrid;
import input.KeyCodes;
import js.Browser;
import js.html.*;
import js.html.audio.*;
import js.JQuery;
import parameter.Mapping;
import parameter.Mapping.Interpolation;
import parameter.Mapping.InterpolationNone;
import parameter.Parameter;
import pixi.core.graphics.*;
import pixi.core.text.*;
import pixi.plugins.app.Application; // modified
import tones.*;
import tones.examples.*;
import tones.utils.AudioNodeRecorder;
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
	
	var randomise:Bool = false;
	var controls:drums.ui.Controls;
	
	var recorder:AudioNodeRecorder;

	public function new() {
		super();

		ready = false;

		controls = new Controls();
		
		initAudio();
		initPixi();

		//initOscilliscope();
		initBeatLines();
		initStepGrid();
		
		initControlRouting();
		
		stageResized();
	}
	
	
	function initControlRouting() {
		
		controls.bpm.addObserver(function(p) { drums.bpm = p.getValue(); } );
		
		controls.muteToggle.addObserver(function(p) {
			if (p.getValue()) {
				outGain.gain.setValueAtTime(0, 0);
			} else {
				outGain.gain.setValueAtTime(controls.volume.getValue(), 0);
			}
		});
		
		controls.playToggle.addObserver(function(p) {
			if (p.getValue()) drums.play();
			else drums.stop();
		});
		
		controls.randomModeToggle.addObserver(function(p) {
			randomise = p.getValue();
		});
		
		controls.recordToggle.addObserver(function(p) {
			
			if (!recorder.recording && p.getValue()) {
				if (!drums.playing) {
					p.setValue(false);
					return;
				}
				trace('recording...');
				recorder.clear();
				recorder.start();
			} else if(recorder.recording){
				trace('stopped recording');
				recorder.stop();
				trace('encoding wav');
				recorder.encodeWAV();
			}
		});
		
		controls.swing.addObserver(function(p) {
			drums.swing = p.getValue();
		});
		
		controls.volume.addObserver(function(p) {
			outGain.gain.setValueAtTime(p.getValue(), 0);
		});
		
		controls.trackMute.connect(function(i, state) {
			drums.tracks[i].mute(state);
		});		
		
		controls.trackShuffle.connect(function(i) {
			drums.tracks[i].randomise();
		});
		
		controls.trackSolo.connect(function(i, state) {
			var tracks = drums.tracks;
			var soloTracks = controls.soloTracks;
			var soloCount = 0;
			for (val in soloTracks) soloCount += val;
			
			var track; var solo;
			
			for (j in 0...8) {
				
				track = tracks[j];
				solo = soloTracks[j];
				
				if (solo == 0 && soloCount > 0) {
					track.otherSolo = true;
				} else if(solo == 1 && soloCount > 1){
					track.otherSolo = true;
				} else {
					track.otherSolo = false;
				}
			}
			
			tracks[i].solo(state);
			for (track in tracks) track.updateOutputState();
			
		});
	}
	

	function initAudio() {
		
		audioContext = AudioBase.createContext();
		
		outGain = audioContext.createGain();
		outGain.gain.value = .25;
		outGain.connect(audioContext.destination);

		drums = new DrumSequencer(audioContext, outGain);
		drums.tick.connect(onSequenceTick);
		drums.ready.connect(onDrumsReady);
		
		recorder = new AudioNodeRecorder(drums.output);
		recorder.wavEncoded.connect(onOutputBufferEncoded);
	}
	
	
	function onOutputBufferEncoded(data:Blob) {
		trace('Encoded wav - ${(data.size>>10) / 1024} MB  (${data.size} bytes)');
		AudioNodeRecorder.forceDownload(data);
	}


	function onDrumsReady() {
		trace('ready');
		ready = true;
		Browser.document.getElementById('load-spinner').remove();
		Browser.document.getElementById('pixi-container').style.display = '';
		controls.bpm.setValue(Math.round(60 + Math.random() * 120));
		controls.swing.setValue(Math.random()*.5);
		controls.volume.setValue(.5);
		drums.play(0);
	}
	
	
	function onSequenceTick(index:Int, time:Float) {
		beatLines.tick(index);
		sequenceGrid.tick(index);

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

		backgroundColor = 0x191B1C;// 0x242627;
		antialias = true;
		onUpdate = tick;
		onResize = stageResized;
		
		width = 898;
		height = 445;
		
		start(Application.AUTO, false, Browser.document.getElementById('pixi-container'));
		stage.x = 1;
	}
	
	override function _onWindowResize(event:Event) {
		width = 898;
		height = 445;
		//height = Browser.window.innerHeight;
		renderer.resize(width, height);
		canvas.style.width = width + "px";
		canvas.style.height = height + "px";
		if (onResize != null) onResize();
	}


	function initOscilliscope() {
		oscilliscope = new Oscilliscope(audioContext, 568, 120);
		stage.addChild(oscilliscope);
		drums.output.connect(oscilliscope.analyser);
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
		var h2 = (height / 2);

		sequenceGrid.x = 26;
		sequenceGrid.y = 26;
		
		beatLines.displayHeight = Math.round(height-40);
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
