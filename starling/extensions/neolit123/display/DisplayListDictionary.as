/*
	DisplayListDictionary.as
	ver.0.2.0

	Copyright (C) 2013 and later Lubomir I. Ivanov (neolit123 [at] gmail)	

	This software is provided 'as-is', without any express or implied
	warranty.  In no event will the authors be held liable for any damages
	arising from the use of this software.

	Permission is granted to anyone to use this software for any purpose,
	including commercial applications, and to alter it and redistribute it
	freely, subject to the following restrictions:

	1. The origin of this software must not be misrepresented; you must not
	claim that you wrote the original software. If you use this software
	in a product, an acknowledgment in the product documentation would be
	appreciated but is not required.
	2. Altered source versions must be plainly marked as such, and must not be
	misrepresented as being the original software.
	3. This notice may not be removed or altered from any source distribution.
*/

package starling.extensions.neolit123.display
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.IBitmapDrawable;
	import flash.display.MovieClip;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.utils.Dictionary;
	import flash.utils.getTimer;

	import starling.extensions.neolit123.text.NativeText;

	import starling.core.Starling;
	import starling.display.DisplayObject;
	import starling.display.DisplayObjectContainer;
	import starling.display.Image;
	import starling.display.MovieClip;
	import starling.display.Sprite;
	import starling.text.TextField;
	import starling.textures.Texture;

	public class DisplayListDictionary extends starling.display.Sprite
	{
		private const DEF_INSTANCE_PREFIX:String = "instance";

		private var dict:Dictionary;
		private var bmd:BitmapData;
		private var matrix:Matrix;
		private var blankMatrix:Matrix;
		private var rect:Rectangle;
		private var mcTextures:Vector.<Vector.<Texture>>;

		public var elapsedTime:uint;
		public var frameRate:uint;
		public var juggleMovieClips:Boolean;
		public var useAlpha:Boolean;
		public var useAlphaColor:uint;
		public var instancePrefix:String;

		public function DisplayListDictionary(_srcClass:Class = null,
		                                      _frameRate:uint = 30,
		                                      _juggleMovieClips:Boolean = true,
		                                      _useAlpha:Boolean = true,
		                                      _useAlphaColor:uint = 0x0):void
		{
			super();
			instancePrefix = DEF_INSTANCE_PREFIX;
			matrix = new Matrix();
			blankMatrix = new Matrix();
			frameRate = _frameRate;
			useAlpha = _useAlpha;
			useAlphaColor = _useAlphaColor;
			juggleMovieClips = _juggleMovieClips;
			if (_srcClass)
				fromClass(_srcClass);
		}

		public function fromInstance(_src:flash.display.DisplayObjectContainer):void
		{
			elapsedTime = getTimer();
			reset();
			traverseConvert(this, _src);
			elapsedTime = getTimer() - elapsedTime;
		}

		public function fromClass(_srcClass:Class):void
		{
			var _src:flash.display.DisplayObjectContainer = new _srcClass();
			elapsedTime = getTimer();
			reset();
			traverseConvert(this, _src);
			_src = null;
			elapsedTime = getTimer() - elapsedTime;
		}

		private function addDisplayObject(_dest:starling.display.DisplayObjectContainer,
		                                  _obj:Object,
		                                  _target:*,
		                                  _path:String,
		                                  _i:int = -1):void
		{
			if (!_target || !_obj)
				return;
			_target.name = _obj.name;
			_target.alpha = _obj.alpha;
			_target.transformationMatrix = _obj.transform.matrix;
			if (_i == -1)
				_dest.addChild(_target);
			else
				_dest.addChildAt(_target, _i);
			dict[_path + _obj.name] = _target;
		}

		private function convertMovieClip(_mc:flash.display.MovieClip):starling.display.MovieClip
		{
			var mc:starling.display.MovieClip;
			var totalFrames:uint = _mc.totalFrames;
			var textures:Vector.<Texture> = Vector.<Texture>([]);
			var fps:uint, i:uint, tw:uint = 0, th:uint = 0;
			var par:flash.display.DisplayObjectContainer = _mc.parent;
			var parIdx:uint = par.getChildIndex(_mc);

			Starling.current.nativeOverlay.addChild(_mc);
			matrix = _mc.transform.matrix;
			_mc.transform.matrix = blankMatrix;
			for (i = 0; i < totalFrames; i++) {
				_mc.gotoAndStop(i + 1);
				rect = _mc.getBounds(_mc.parent);
				tw = (rect.width > tw) ? rect.width : tw;
				th = (rect.height > th) ? rect.height : th;
			}
			for (i = 0; i < totalFrames; i++) {
				_mc.gotoAndStop(i + 1);
				rect = _mc.getBounds(_mc.parent);
				bmd = new BitmapData(Math.ceil(tw), Math.ceil(tw),
					useAlpha, useAlphaColor);
				bmd.draw(_mc);
				textures.push(Texture.fromBitmapData(bmd));
				rect = null;
			}
			par.addChildAt(_mc, parIdx);
			_mc.transform.matrix = matrix;
			fps = (_mc.loaderInfo) ? _mc.loaderInfo.frameRate : frameRate;
			mc = new starling.display.MovieClip(textures, fps);
			mcTextures.push(textures);
			if (juggleMovieClips)
				Starling.juggler.add(mc);
			return mc;
		}

		private function hasUserInstances(_obj:flash.display.DisplayObjectContainer):Boolean
		{
			var i:uint, len:uint = _obj.numChildren;
			var nm:String;
			var child:Object;

			if (len < 2)
				return false;
			for (i = 0; i < len; i++) {
				child = _obj.getChildAt(i);
				if (child.name.indexOf(instancePrefix) != 0)
					return true;
			}
			return false;
		}

		private function traverseConvert(_dest:starling.display.DisplayObjectContainer,
		                                 _src:flash.display.DisplayObjectContainer,
		                                 _path:String = ""):void
		{
			const txtDynOffsetW:uint = 1;
			const txtInpOffsetW:uint = 2;
			var i:uint, len:uint = _src.numChildren;
			var img:Image;
			var sp:starling.display.Sprite;
			var mc:starling.display.MovieClip;
			var obj:Object;
			var target:starling.display.DisplayObject;
			var fmt:flash.text.TextFormat;
			var txt:starling.text.TextField;
			var ntxt:NativeText;

			while (i < len) {
				obj = _src.getChildAt(i);
				// a MovieClip with with more than one frame. children are ignored.
				if (obj is flash.display.MovieClip && obj.totalFrames > 1) {
					mc = convertMovieClip(flash.display.MovieClip(obj));
					addDisplayObject(_dest, obj, mc, _path, i);
				// a generic container that has more than one child. recurse here.
				} else if (obj is flash.display.DisplayObjectContainer &&
						   hasUserInstances(flash.display.DisplayObjectContainer(obj))) {
					sp = new Sprite();
					addDisplayObject(_dest, obj, sp, _path, i);
					traverseConvert(sp, flash.display.DisplayObjectContainer(obj),
						(_path == "") ? (obj.name + ".") : (_src.name + "." + obj.name + "."));
				} else if (obj is flash.text.TextField) {
					fmt = flash.text.TextField(obj).defaultTextFormat;
					// dynamic TF
					if (obj.type == "dynamic") {
						txt = new starling.text.TextField(uint(obj.width) + txtDynOffsetW,
							uint(obj.height), obj.text, fmt.font, Number(fmt.size),
							uint(fmt.color), fmt.bold);
						txt.vAlign = "top";
						txt.hAlign = fmt.align;
						txt.border = obj.border;
						target = txt;
					// input TF
					} else {
						ntxt = new NativeText(obj.numLines);
						if (fmt.bold)
							ntxt.fontWeight = "bold";
						ntxt.width = uint(obj.width) + txtInpOffsetW;
						ntxt.text = obj.text;
						ntxt.textAlign = fmt.align;
						ntxt.color = uint(fmt.color);
						ntxt.fontFamily = fmt.font;
						ntxt.background = obj.background;
						ntxt.backgroundColor = obj.backgroundColor;
						ntxt.borderColor = obj.borderColor;
						ntxt.border = obj.border;
						ntxt.fontSize = Number(fmt.size);
						ntxt.autoCorrect = false;
						target = ntxt;
					}
					addDisplayObject(_dest, obj, target, _path, i);
				// a generic object with one or no children
				} else {
					matrix = obj.transform.matrix;
					obj.transform.matrix = blankMatrix;
					rect = obj.getBounds(obj.parent);
					bmd = new BitmapData(Math.ceil(rect.width + rect.x - obj.x),
						Math.ceil(rect.height + rect.y - obj.y),
						useAlpha, useAlphaColor);
					bmd.draw(IBitmapDrawable(obj));
					img = new Image(Texture.fromBitmapData(bmd));
					target = img;
					obj.transform.matrix = matrix;
					addDisplayObject(_dest, obj, target, _path, i);
					rect = null;
				}
				i++;
			}
		}

		override public function flatten():void
		{
			var obj:Object;
			for (obj in dict) {
				if (dict[obj] is starling.display.Sprite)
					dict[obj].flatten();
			}
			super.flatten();
		}

		override public function unflatten():void
		{
			var obj:Object;
			for (obj in dict)
				if (dict[obj] is starling.display.Sprite)
					dict[obj].unflatten();
			super.unflatten();
		}

		public function get(_str:String):*
		{
			return dict[_str];
		}

		public function set(_str:String, _val:*):void
		{
			var d:starling.display.DisplayObject;
			var par:starling.display.DisplayObjectContainer;
			var idx:uint;

			d = get(_str);
			if (d != null) {
				if (d.parent) {
					par = d.parent;
					idx = par.getChildIndex(d);
					par.removeChild(d);
				}
				d.dispose();
				d = null;
			}
			if (!_val) {
				dict[_str] = null;
				delete dict[_str];
				return;
			}
			dict[_str] = _val;
			if (_val && par)
				par.addChildAt(_val, idx);
		}

		public function remove(_str:String):void
		{
			set(_str, null);
			delete dict[_str];
		}

		private function clearMCTextures():void
		{
			var i:uint, j:uint, lenTotal:uint, len:uint;

			if (!mcTextures)
				mcTextures = Vector.<Vector.<Texture>>([]);
			lenTotal = mcTextures.length;
			for (i = 0;  i < lenTotal; i++) {
				len = mcTextures[i].length;
				for (j = 0; j < len; j++) {
					mcTextures[i][j].dispose();
					mcTextures[i][j] = null;
				}
				mcTextures[i].length = 0;
				mcTextures[i] = null;
			}
			mcTextures.length = 0;
		}

		public function reset():void
		{
			var obj:Object;
			if (!dict)
				dict = new Dictionary();
			for (obj in dict) {
				if (dict[obj].parent)
					dict[obj].parent.removeChild(dict[obj]);
				dict[obj].dispose();
				dict[obj] = null;
				delete dict[obj];
			}
			clearMCTextures();
		}

		override public function dispose():void
		{
			matrix = null;
			blankMatrix = null;
			rect = null;
			reset();
			mcTextures = null;
			dict = null;
			if (this.parent)
				this.parent.removeChild(this);
			super.dispose();
		}
	}
}
