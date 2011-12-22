The SCSQLite is a wrapper of SQLite. (http://sqlite.org/)


Getting Started
=================
Just copy the files `SCSQLite.h` and `SCSQLite.m` for your project.
Then if your project is using the ARC is going on (in Xcode 4, that's under the Sparrow target -> Build Phases -> Compile Sources) and add the `SCSQLite.m` the flag `-fno-objc-arc`

In the class `SCSQLite.h` is necessary to put the name of the database in the variable `kDataBase`



Example Usage
=============

To use the component is very easy. Import the header for your class.

	# import "SCSQLite.h"

	// To create, insert, update and delete use this method
	BOOL success = [SCSQLite executeSQL:@"insert into Category (name) values ​​('Lucas')"];


	// To use this method select
	NSArray *result = [SCSQLite selectRowSQL:@"select * from Category"];


License
=============

SCSQLite is licensed under the MIT License:

Copyright (c) 2011 Lucas Correa (http://www.lucascorrea.com/)

Permission is hereby-granted, free of charge, to any person Obtaining a copy of this software and Associated documentation files (the "Software"), to deal in the Software without restriction, including without Limitation the rights to use, copy, modify, merge , publish, distribute, sublicense, and / or sell copies of the Software, and to permit persons to Whom the Software is furnished to the so, subject to the Following conditions:

The above copyright notice and this permission notice Shall be included in all copies or Substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE Warranties OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE Liable FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, Whether IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, Arising FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR THE OTHER IN Dealings SOFTWARE.