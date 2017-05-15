/*
 *  Copyright 2013 Tony Tyson <teesquared@twistedwords.net>
 *  Copyright 2010, 2011 Vladimir Panteleev <vladimir@thecybershadow.net>
 *  This file is ironically part of RABCDAsm.
 *
 *  RABCDAsm is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  RABCDAsm is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with RABCDAsm.  If not, see <http://www.gnu.org/licenses/>.
 */

module swfobfuscatoroptions;

import std.getopt;

class SwfObfuscatorOptions
{
	bool allowDebug = false;
	bool help = false;
	bool quiet = false;
	bool skipCacheAsBitmapByte = false;
	bool test = false;
	bool verbose = false;
	bool version_ = false;

	string excludesFile = null;
	string fixedNamesFile = null;
	string includesFile = null;
	string outputExt = "out";
	string namePrefix = "";

	string[] globalFiles;
	string[] jsonNames;

	const string optionText = q"EOS
Options:
      --allowDebug               allow enable debugger tags and debug opcodes
  -e, --excludes=FILE            exclude names that match any listed in FILE
  -f, --fixed=FILE               use a fixed renaming for names listed in FILE
  -g, --globalFile=FILE          the global file to use (multiple supported, default: "./playerglobal.swc")
  -h, --help                     display this help and exit
  -i, --includes=FILE            include names that match any listed in FILE
  -j, --json                     the symbol name of a json binary tag to process (multiple supported)
  -n, --namePrefix               prefix for each generated name (default: "")
  -o, --outputExt                the output file extension (default: "out")
  -q, --quiet                    do not print renames
      --skipCacheAsBitmapByte    skip reading an extra byte for PlaceObject3 tags
  -t, --test                     load a swf, write it back out, and report any inconsistencies
  -v, --verbose                  enable verbose output
      --version                  output version information and exit
EOS";

	const string sealText;

	this(ref string[] args, const ref string sealText)
	{
		this.sealText = sealText;

		getopt(
			args,
			"allowDebug", &allowDebug,
			"excludes|e", &excludesFile,
			"fixed|f", &fixedNamesFile,
			"globalFile|g", &globalFiles,
			"help|h", &help,
			"includes|i", &includesFile,
			"json|j", &jsonNames,
			"namePrefix|n", &namePrefix,
			"outputExt|o", &outputExt,
			"quiet|q", &quiet,
			"skipCacheAsBitmapByte", &skipCacheAsBitmapByte,
			"test|t", &test,
			"verbose|v", &verbose,
			"version", &version_,
		);

		if (globalFiles.length == 0)
			globalFiles ~= "playerglobal.swc";
	}
}
