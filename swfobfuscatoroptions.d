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
	bool fart = false;
	bool funny = false;
	bool help = false;
	bool quiet = false;
	bool test = false;
	bool verbose = false;
	bool version_ = false;

	string excludesFile = null;
	string fixedNamesFile = null;
	string includesFile = null;
	string outputExt = "out";
	string playerGlobalFile = "playerglobal.swc";

	string[] jsonNames;

	const string optionText = q"EOS
Options:
  -e, --excludes=FILE            exclude names that match any listed in FILE
      --fart                     don't use this option
  -f, --fixed=FILE               use a fixed renaming for names listed in FILE
      --funny                    this option is undocumented
  -h, --help                     display this help and exit
  -i, --includes=FILE            include names that match any listed in FILE
  -j, --json                     the symbol name of a json binary tag you want processed (multiple supported)
  -o, --outputExt                the output file extension (default: "out")
  -p, --playerGlobal=FILE        the player global file to use (default: "./playerglobal.swc")
  -q, --quiet                    do not print renames
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
			"excludes|e", &excludesFile,
			"fart", &fart,
			"fixed|f", &fixedNamesFile,
			"funny", &funny,
			"json|j", &jsonNames,
			"help|h", &help,
			"includes|i", &includesFile,
			"outputExt|o", &outputExt,
			"playerGlobal|p", &playerGlobalFile,
			"quiet|q", &quiet,
			"test|t", &test,
			"verbose|v", &verbose,
			"version", &version_,
		);
	}
}
