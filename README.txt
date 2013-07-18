DisplayListDictionary

INTRODUCTION:

DisplayListDictionary provides the means for you to convert
a dynamic Flash MovieClip DisplayList (DL) structure into a Starling
DL structure.

Starling's TextField class is used to render 'dynamic' TextFields
and also a heavily modified Adobe's NativeText is used to render
'input' TextFields using StageText, thus AIR is required.

MovieClips are also converted, with a frame rate given by the public
"frameRate" parameter. The complete nested display list should be traversed
and converted, except where a MovieClip with multiple frames is found,
in which case it is treated as a sequence of static textures per frame.
No child instances will be reachable in such cases.

You can take a look at the conversation diagram in "images/dld-diagram.png".

Access to the converted display list is straight-forward, provided
by a Dictionary class and the get("some.nested.location") method.
Removal of a display list entry is possible via the remove() method.
Also there is the set("some.location", mySprite) method which
can be used to replace a specific instance.

USAGE:

// --------------------------------------------------------------
// create and export your classes in a SWC file using tools
// like Flash IDE, then make sure you import said SWC in your project.
// ...

// create a DLD instance
var dld:DisplayListDictionary = new DisplayListDictionary();

// use a Class object
dld.fromClass(MyLibraryClass);

// use a DOC instance
dld.fromInstance(MyLibraryInstance);

// access a 'dynamic' TextField "MyLibraryInstance.someMC.someTF"
var txt:starling.display.TextField = dld.get("someMC.someTF");
txt.text = "hello";

// access a MC named "someAnim" under the root node
var mc:starling.display.MovieClip = dld.get("someAnim");
// it will be automatically added to the juggler by default.
// set "juggleMovieClips" to false to override
mc.stop();

// use set() to replace a DisplayObject
dld.set("someAnim", myMovieClip);

// remove() will delete a DisplayObject
dld.remove("someAnim");

// flatten(), unflatten()
dld.flatten();
dld.unflatten();

// dispose() should dispose of all resources, while reset()
// should only reset the Dictionary and remove all DO's, but leave the
// clas active. reset() is also called by fromClass(), fromInstance(),
// and dispose().
dld.reset();
dld.dispose();
dld = null;
// -----------------------------------------------------------

PERFORMANCE:
	- slow! this class will cause a blocking operation of N seconds!
	- to minimize overhead organize your display list in a smart way.
	if a container has many children, but none of them have user defined
	names the entire container will be converted as a single starling Image.
	- converting large keyframe animation is very slow
	- you can benchmark using the "elapsedTime" public property

WHAT IS MISSING:
	- color transforms, but alpha does work
	- flash filters. an example of a better practice would be to design your
	UI in Flash IDE	and call "Convert to Bitmap" on a MC that has filters
	applied to it.	
	- password mode in text fields
	- something else?

POSSIBLE IMPROVEMENTS:
	- more memory testing and optimizations
	- safer/better handling of DisplayObject bounds..
	- scaling and positioning tests
	- further optimize the drawing of images. try collecting
	all static children from a container and draw them on a single texture.
	- optional async rendering

IDEAS/CONTRIBUTIONS:
	- you can contact me at "neolit123 [at] gmail"

lubomir
--
