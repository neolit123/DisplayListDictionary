//  Adobe(R) Systems Incorporated Source Code License Agreement
//  Copyright(c) 2006-2011 Adobe Systems Incorporated. All rights reserved.
//
//  Please read this Source Code License Agreement carefully before using
//  the source code.
//
//  Adobe Systems Incorporated grants to you a perpetual, worldwide, non-exclusive,
//  no-charge, royalty-free, irrevocable copyright license, to reproduce,
//  prepare derivative works of, publicly display, publicly perform, and
//  distribute this source code and such derivative works in source or
//  object code form without any attribution requirements.
//
//  The name "Adobe Systems Incorporated" must not be used to endorse or promote products
//  derived from the source code without prior written permission.
//
//  You agree to indemnify, hold harmless and defend Adobe Systems Incorporated from and
//  against any loss, damage, claims or lawsuits, including attorney's
//  fees that arise or result from your use or distribution of the source
//  code.
//
//  THIS SOURCE CODE IS PROVIDED "AS IS" AND "WITH ALL FAULTS", WITHOUT
//  ANY TECHNICAL SUPPORT OR ANY EXPRESSED OR IMPLIED WARRANTIES, INCLUDING,
//  BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//  FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  ALSO, THERE IS NO WARRANTY OF
//  NON-INFRINGEMENT, TITLE OR QUIET ENJOYMENT.  IN NO EVENT SHALL ADOBE
//  OR ITS SUPPLIERS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
//  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
//  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
//  OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
//  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
//  OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOURCE CODE, EVEN IF
//  ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

/*
	NativeText.as
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

/*
	modifications by Lubomir I. Ivanov (neolit123@gmail.com), 04.02.2013
	- adapted the class to Starling
	- better memory management
	- allow transparency when drawing to a bitmap
	- allow colored backgrounds
	- renamed various methods (e.g. freeze() -> flatten())
	- smart reposition when unflatten (per frame viewport update)
	- allow re-rendering when a parameter is changed, while in flatten() mode

	Notes:
		- border thickness larger than 1 does not work very well
		- there might be some memory leaks left
*/

package starling.extensions.neolit123.text
{
	import flash.display.BitmapData;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.FocusEvent;
	import flash.events.KeyboardEvent;
	import flash.events.SoftKeyboardEvent;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.text.StageText;
	import flash.text.StageTextInitOptions;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.text.TextLineMetrics;
	import flash.text.engine.FontPosture;
	import flash.text.engine.FontWeight;

	import starling.core.Starling;
	import starling.display.Image;
	import starling.display.Sprite;
	import starling.events.TouchEvent;
	import starling.events.Touch;
	import starling.events.TouchPhase;
	import starling.textures.Texture;

	[Event(name="change",                 type="flash.events.Event")]
	[Event(name="focusIn",                type="flash.events.FocusEvent")]
	[Event(name="focusOut",               type="flash.events.FocusEvent")]
	[Event(name="keyDown",                type="flash.events.KeyboardEvent")]
	[Event(name="keyUp",                  type="flash.events.KeyboardEvent")]
	[Event(name="softKeyboardActivate",   type="flash.events.SoftKeyboardEvent")]
	[Event(name="softKeyboardActivating", type="flash.events.SoftKeyboardEvent")]
	[Event(name="softKeyboardDeactivate", type="flash.events.SoftKeyboardEvent")]

	public class NativeText extends starling.display.Sprite
	{
		public var st:StageText;
		private var numberOfLines:uint;
		private var snapshot:starling.display.Image;
		private var texture:starling.textures.Texture;
		private var lineMetric:TextLineMetrics;
		private var stio:StageTextInitOptions;
		private var bmd:BitmapData;
		private var viewPortRect:Rectangle;
		private var assets:flash.display.Sprite;
		private var assetsSnapshot:starling.display.Image;
		private var assetsTexture:starling.textures.Texture;
		private var assetBackground:Shape;
		private var assetBorder:Shape;
		private var localPt:Point, globalPt:Point;
		private var _width:uint, _height:uint;
		private var _borderThickness:uint = 0;
		private var _borderColor:uint = 0x000000;
		private var _backgroundColor:uint = 0xffffff;
		private var _background:Boolean;
		private var _border:Boolean;
		private var _borderCornerSize:uint = 0;
		private var _flattenFlag:Boolean;
		private var oldX:Number;
		private var oldY:Number;

		public function NativeText(_numberOfLines:uint = 1)
		{
			super();

			addEventListener(starling.events.Event.ADDED_TO_STAGE, onAddedToStage);
			addEventListener(starling.events.Event.REMOVED_FROM_STAGE, onRemoveFromStage);

			localPt = new Point();
			globalPt = new Point();
			viewPortRect = new Rectangle();
			assets = new flash.display.Sprite();
			assetBackground = new flash.display.Shape();
			assetBorder = new flash.display.Shape();
			assets.addChild(assetBackground);
			assets.addChild(assetBorder);
			numberOfLines = _numberOfLines;
			stio = new StageTextInitOptions((numberOfLines > 1));
			st = new StageText(stio);
			fontSize = 12;
			width = 40;
			height = 80;
			borderThickness = 1;
		}

		public override function addEventListener(type:String, listener:Function):void
		{
			if (isEventTypeStageTextSpecific(type))
				st.addEventListener(type, listener);
			else
				super.addEventListener(type, listener);
		}

		public override function removeEventListener(type:String, listener:Function):void
		{
			if (isEventTypeStageTextSpecific(type))
				st.removeEventListener(type, listener);
			else
				super.removeEventListener(type, listener);
		}

		private function isEventTypeStageTextSpecific(type:String):Boolean
		{
			return (type == flash.events.Event.CHANGE ||
					type == FocusEvent.FOCUS_IN ||
					type == FocusEvent.FOCUS_OUT ||
					type == KeyboardEvent.KEY_DOWN ||
					type == KeyboardEvent.KEY_UP ||
					type == SoftKeyboardEvent.SOFT_KEYBOARD_ACTIVATE ||
					type == SoftKeyboardEvent.SOFT_KEYBOARD_ACTIVATING ||
					type == SoftKeyboardEvent.SOFT_KEYBOARD_DEACTIVATE);
		}

		private function onAddedToStage(e:starling.events.Event):void
		{
			st.stage = Starling.current.nativeStage;
			st.addEventListener(flash.events.FocusEvent.FOCUS_OUT, focusOutHandler);
			renderTF();
			flatten();
		}

		private function onRemoveFromStage(e:starling.events.Event):void
		{
			this.removeEventListener(starling.events.Event.ENTER_FRAME, onEnterFrame);
		}

		private function onEnterFrame(e:starling.events.Event):void
		{
			st.viewPort = updateViewportAnchor();
			if (oldX != st.viewPort.x || oldY != st.viewPort.y) {
				st.stage.focus = null;
				flatten();
			}
		}

		public function set borderThickness(borderThickness:uint):void
		{
			_borderThickness = borderThickness;
			renderTF();
		}

		public function get borderThickness():uint
		{
			return _borderThickness;
		}

		public function set border(_val:Boolean):void
		{
			_border = _val;
			renderTF();
		}

		public function get border():Boolean
		{
			return _border;
		}

		public function set borderColor(borderColor:uint):void
		{
			_borderColor = borderColor;
			renderTF();
		}

		public function get borderColor():uint
		{
			return _borderColor;
		}

		public function set borderCornerSize(borderCornerSize:uint):void
		{
			_borderCornerSize = borderCornerSize;
			renderTF();
		}

		public function get borderCornerSize():uint
		{
			return _borderCornerSize;
		}

		public function set autoCapitalize(autoCapitalize:String):void
		{
			st.autoCapitalize = autoCapitalize;
		}

		public function set autoCorrect(autoCorrect:Boolean):void
		{
			st.autoCorrect = autoCorrect;
		}

		public function set color(color:uint):void
		{
			st.color = color;
		}

		public function set displayAsPassword(displayAsPassword:Boolean):void
		{
			st.displayAsPassword = displayAsPassword;
		}

		public function set editable(editable:Boolean):void
		{
			st.editable = editable;
		}

		public function set fontFamily(fontFamily:String):void
		{
			st.fontFamily = fontFamily;
		}

		public function set fontPosture(fontPosture:String):void
		{
			st.fontPosture = fontPosture;
		}

		public function set fontSize(fontSize:Number):void
		{
			st.fontSize = fontSize;
			renderTF();
		}

		public function set fontWeight(fontWeight:String):void
		{
			st.fontWeight = fontWeight;
		}

		public function set locale(locale:String):void
		{
			st.locale = locale;
		}

		public function set maxChars(maxChars:int):void
		{
			st.maxChars = maxChars;
		}

		public function set restrict(restrict:String):void
		{
			st.restrict = restrict;
		}

		public function set returnKeyLabel(returnKeyLabel:String):void
		{
			st.returnKeyLabel = returnKeyLabel;
		}

		public function get selectionActiveIndex():int
		{
			return st.selectionActiveIndex;
		}

		public function get selectionAnchorIndex():int
		{
			return st.selectionAnchorIndex;
		}

		public function set softKeyboardType(softKeyboardType:String):void
		{
			st.softKeyboardType = softKeyboardType;
		}

		public function set text(text:String):void
		{
			st.text = text;
		}

		public function get text():String
		{
			return st.text;
		}

		public function set textAlign(textAlign:String):void
		{
			st.textAlign = textAlign;
		}

		public override function set visible(visible:Boolean):void
		{
			visible = visible;
			st.visible = visible;
		}

		public function get multiline():Boolean
		{
			return st.multiline;
		}

		public function assignFocus():void
		{
			st.assignFocus();
		}

		public function selectRange(anchorIndex:int, activeIndex:int):void
		{
			st.selectRange(anchorIndex, activeIndex);
		}

		override public function flatten():void
		{
			var viewPortRectangle:Rectangle;
			var mtx:Matrix;

			if (_flattenFlag)
				return;
			viewPortRectangle = getViewPortRectangle();
			_flattenFlag = true;
			updateViewportAnchor();
			st.viewPort = viewPortRectangle;
			oldX = st.viewPort.x;
			oldY = st.viewPort.y;
			if (bmd) {
				bmd.dispose();
				bmd = null;
			}
			bmd = new BitmapData(st.viewPort.width, st.viewPort.height, true, 0x0);
			st.drawViewPortToBitmapData(bmd);
			if (snapshot) {
				if (snapshot.parent)
					removeChild(snapshot);
				snapshot.dispose();
			}
			snapshot = new Image(Texture.fromBitmapData(bmd));
			snapshot.x = 1; // ?
			snapshot.y = 1;
			addChild(snapshot);
			st.visible = false;
			bmd.dispose();
			bmd = null;
			mtx = null;
			this.removeEventListener(starling.events.Event.ENTER_FRAME, onEnterFrame);
			this.removeEventListener(TouchEvent.TOUCH, touchHandler);
			this.addEventListener(TouchEvent.TOUCH, touchHandler);
			super.flatten();
		}

		override public function unflatten():void
		{
			if (!_flattenFlag)
				return;
			_flattenFlag = false;
			if (snapshot != null && contains(snapshot)) {
				removeChild(snapshot);
				snapshot = null;
				st.visible = true;
			}
			if (bmd) {
				bmd.dispose();
				bmd = null;
			}
			updateViewportAnchor();
			addEventListener(starling.events.Event.ENTER_FRAME, onEnterFrame);
			this.removeEventListener(TouchEvent.TOUCH, touchHandler);
			super.unflatten();
		}

		private function focusOutHandler(_e:flash.events.FocusEvent):void
		{
			flatten();
		}

		private function touchHandler(_e:TouchEvent):void
		{
			var touch:Touch = _e.getTouch(this, TouchPhase.ENDED);
  			if (touch == null)
				return;
			unflatten();
			selectRange(st.text.length, st.text.length);
			assignFocus();
		}

		public override function set width(width:Number):void
		{
			_width = width;
			renderTF();
		}

		public override function get width():Number
		{
			return _width;
		}

		public override function set height(height:Number):void
		{
			// nop
		}

		public override function get height():Number
		{
			return _height;
		}

		public override function set x(x:Number):void
		{
			super.x = x;
			renderTF();
		}

		public override function set y(y:Number):void
		{
			super.y = y;
			renderTF();
		}

		private function reflatten(_wasFlatten:Boolean):void
		{
			_flattenFlag = _wasFlatten;
			if (_wasFlatten)
				flatten();
		}

		private function renderTF():void
		{
			var mtx:Matrix;
			var wasFlatten:Boolean = _flattenFlag;
			// if (wasFlatten)
				// unflatten();
			if (stage == null || !stage.contains(this)) return;
			lineMetric = null;
			calculateHeight();
			st.viewPort = getViewPortRectangle();

			// draw border
			if (!_background && !_border) {
				// reflatten(wasFlatten);
				return;
			}
			drawBackground(assetBackground);
			drawBorder(assetBorder);
			if (bmd) {
				bmd.dispose();
				bmd = null;
			}
			bmd = new BitmapData(st.viewPort.width + 2, st.viewPort.height, true, 0x0);
			bmd.draw(assets);
			if (assetsSnapshot) {
				if (assetsSnapshot.parent)
					removeChild(assetsSnapshot);
				assetsSnapshot.dispose();
				assetsSnapshot = null;
			}
			assetsSnapshot = new starling.display.Image(Texture.fromBitmapData(bmd));
			addChildAt(assetsSnapshot, 0);
			mtx = null;
			bmd.dispose();
			bmd = null;
			// reflatten(wasFlatten);
		}

		public function set backgroundColor(backgroundColor:uint):void
		{
			_backgroundColor = backgroundColor;
      		renderTF();
		}

 	  	public function get backgroundColor():uint
		{
			return _backgroundColor;
		}

		public function set background(_val:Boolean):void
		{
			_background = _val;
			renderTF();
		}

		public function get background():Boolean
		{
			return _background;
		}

		private function updateViewportAnchor():Rectangle
		{
			var localX:int = super.x;
			var localY:int = super.y;
			localPt.x = localX;
			localPt.y = localY;
			localToGlobal(localPt, globalPt);
			viewPortRect.x = int(globalPt.x - localX) + borderThickness;
			viewPortRect.y = int(globalPt.y - localY) + borderThickness;
			return viewPortRect;
		}

		private function getViewPortRectangle():Rectangle
		{
			updateViewportAnchor();
			var totalFontHeight:Number = getTotalFontHeight();
			viewPortRect.width = Math.round(_width - (borderThickness * 2.5));
			viewPortRect.height = Math.round((totalFontHeight + (totalFontHeight - st.fontSize)) * numberOfLines);
			return viewPortRect;
		}

		private function drawBackground(s:flash.display.Shape):void
		{
			s.graphics.clear();
			if (_background) {
				s.graphics.beginFill(_backgroundColor, 1);
				s.graphics.drawRoundRect(0, 0, _width - (borderThickness), _height, borderCornerSize, borderCornerSize);
				s.graphics.endFill();
			}
		}

		private function drawBorder(s:flash.display.Shape):void
		{
			s.graphics.clear();
			if (_border) {
				s.graphics.lineStyle(borderThickness, borderColor);
				s.graphics.drawRoundRect(0, 0, _width - (borderThickness), _height, borderCornerSize, borderCornerSize);
			}
		}

		private function calculateHeight():void
		{
			var totalFontHeight:Number = getTotalFontHeight();
			_height = (totalFontHeight * numberOfLines) + (borderThickness * 2) + 4;
		}

		private function getTotalFontHeight():Number
		{
			if (lineMetric != null)
				return (lineMetric.ascent + lineMetric.descent);
			var textField:TextField = new TextField();
			var textFormat:TextFormat = new TextFormat(st.fontFamily, st.fontSize, null,
				(st.fontWeight == FontWeight.BOLD), (st.fontPosture == FontPosture.ITALIC));
			textField.defaultTextFormat = textFormat;
			textField.text = "QQQ";
			lineMetric = textField.getLineMetrics(0);
			textField = null;
			textFormat = null;
			return (lineMetric.ascent + lineMetric.descent);
		}

		override public function dispose():void
		{
			removeEventListener(flash.events.FocusEvent.FOCUS_OUT, focusOutHandler);
			if (stio) {
				st.dispose();
				st = null;
				stio = null;
			}
			if (snapshot) {
				if (snapshot.parent)
					removeChild(snapshot);
				snapshot.dispose();
				snapshot = null;
			}
			if (bmd) {
				bmd.dispose();
				bmd = null;
				snapshot = null;
			}
			assets = null;
			assetBackground = null;
			assetBorder = null;
			viewPortRect = null;

			if (assetsSnapshot) {
				removeChild(assetsSnapshot);
				assetsSnapshot.dispose();
				assetsSnapshot = null;
			}

			if (this.parent)
				this.parent.removeChild(this);

			localPt = null;
			globalPt = null;

			this.removeEventListener(TouchEvent.TOUCH, touchHandler);
			this.removeEventListener(starling.events.Event.ENTER_FRAME, onEnterFrame);
			this.removeEventListener(starling.events.Event.ADDED_TO_STAGE, onAddedToStage);
			this.removeEventListener(starling.events.Event.REMOVED_FROM_STAGE, onRemoveFromStage);
			super.dispose();
		}
	}
}
