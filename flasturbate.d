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

import std.exception;
import std.process;
import std.random;
import std.regex;
import std.stdio;
import std.string;

import swfobfuscator;
import swfobfuscatoroptions;
import swftester;

const string versionNumber = "1.0.4";
const string versionText = "flasturbate version " ~ versionNumber;

const string usageText = q"EOS
Usage: flasturbate [OPTION] FILE ...
A tool that lets you play with your swf.
EOS";

const string copyrightText = q"EOS
Copyright (c) 2013 Tony Tyson <teesquared@twistedwords.net>
Copyright (c) 2010, 2011 Vladimir Panteleev <vladimir@thecybershadow.net>
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE,
to the extent permitted by law.
EOS";

const string sealText = "OBFUSCATED BY FLASTURBATE!";

void showUsage(string optionText)
{
	stderr.writeln(usageText);
	stderr.writeln(optionText);
}

void showCopyright()
{
	stderr.writeln(copyrightText);
}

void showVersion()
{
	stderr.writeln(versionText);
	showCopyright();
}

int main(string[] args)
{
	try
	{
		SwfObfuscatorOptions opt = new SwfObfuscatorOptions(args, sealText);

		if (opt.version_)
		{
			showVersion();
			return 0;
		}

		if (opt.help || (args.length == 1))
		{
			showUsage(opt.optionText);
			return 0;
		}

		if (args.length > 1)
			if (opt.test)
			{
				SwfTester swfTester = new SwfTester(opt);

				foreach (arg; args[1..$])
					swfTester.testSwf(arg);
			}
			else
			{
				SwfObfuscator swfObfuscator = new SwfObfuscator(opt);

				foreach (arg; args[1..$])
					swfObfuscator.processSwf(arg);

				swfObfuscator.reportWarnings();
			}
	}
	catch (Exception e)
	{
		version (assert)
		{
			stderr.writefln("Error: %s", e);
		}
		else
		{
			stderr.writefln("Error: %s\n", e.msg);
		}

		return 1;
	}

	return 0;
}
