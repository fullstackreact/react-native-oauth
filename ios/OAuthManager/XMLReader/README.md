# XMLReader

This project comes from a component developed by Troy Brant and published on his website : http://troybrant.net/blog/2010/09/simple-xml-to-nsdictionary-converter/

I'm open sourcing some of the updates I've made on it.


## Usage

	NSData *data = ...; // some data that can be received from remote service
	NSError *error = nil;
	NSDictionary *dict = [XMLReader dictionaryForXMLData:data 
	                                             options:XMLReaderOptionsProcessNamespaces 
	                                               error:&error];


## Requirements

Xcode 4.4 and above because project use the "auto-synthesized property" feature.


## FAQ

#### Sometimes I get an `NSDictionary` while I must get an `NSArray`, why ?

In the algorithm of the `XMLReader`, when the parser found a new tag it automatically creates an `NSDictionary`, if it found another occurrence of the same tag at the same level in the XML tree it creates another dictionary and put both dictionaries inside an `NSArray`. 

The consequence is: if you have a list that contains only one item, you will get an `NSDictionary` as result and not an `NSArray`. 
The only workaround is to check the class of the object contained for in the dictionary using `isKindOfClass:`. See sample code below :
	
	NSData *data = ...;
	NSError *error = nil;
	NSDictionary *dict = [XMLReader dictionaryForXMLData:data error:&error];
	
	NSArray *list = [dict objectForKey:@"list"];
	if (![list isKindOfClass:[NSArray class]])
	{
		// if 'list' isn't an array, we create a new array containing our object
		list = [NSArray arrayWithObject:list];
	}
	
	// we can loop through items safely now
	for (NSDictionary *item in list)
	{
		// ...
	}
	                                           

#### I don't have enable ARC on my project, how can I use your library ?

You have 2 options: 

* Use the branch "[no-objc-arc](https://github.com/amarcadet/XMLReader/tree/no-objc-arc)" that use manual reference counting.
* **Better choice:** add the "-fobjc-arc" compiler flag on `XMLReader.m` file in your build phases.

#### I have trust issues, I don't want ARC, I prefer MRC, what can I do ?

Well, nobody is perfect but, still, you can use the branch "[no-objc-arc](https://github.com/amarcadet/XMLReader/tree/no-objc-arc)".


## Contributions

Thanks to the original author of this component Troy Brant and to [Divan "snip3r8" Visagie](https://github.com/snip3r8) for providing ARC support.


## License

Copyright (C) 2012 Antoine Marcadet

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/amarcadet/XMLReader/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

