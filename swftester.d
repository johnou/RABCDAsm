/*
 *  Copyright 2013 Tony Tyson <teesquared@twistedwords.net>
 *  Copyright 2010, 2011 Vladimir Panteleev <vladimir@thecybershadow.net>
 *  This file is part of RABCDAsm.
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

module swftester;

import std.exception;
import std.file;
import std.stdio;

import swffile;
import tagutils;

import abcfile;
import binfile;
import expfile;
import frmfile;
import impfile;
import pobfile;
import sprfile;
import symfile;

class SwfTester
{
	void testTag(uint count, uint subcount, ref SWFFile.Tag tag, ubyte swfver)
	{
		void showTagInfo(T)(T t, bool withHexDump = false)
		{
			writefln("TAG: %s", t);
			writefln("TAG: %d(%d) %s %d %s", count, subcount, tagNames[tag.type], tag.length, tag.forceLongLength);
			if (withHexDump)
				writeln(getHexDumpString(tag.data, "TAG"));
		}

		void readAndReplaceTag(T)()
		{
			T t = readTag!(T)(tag);

			if (t && replaceTagData(tag, t.write(), true))
				showTagInfo(t);
		}

		try
		{
			readAndReplaceTag!(ABCFile)();
			readAndReplaceTag!(BinFile)();
			readAndReplaceTag!(FrmFile)();
			readAndReplaceTag!(ExpFile)();
			readAndReplaceTag!(ImpFile)();

			PobFile pob = readTagVer!(PobFile)(tag, swfver);

			if (pob && replaceTagData(tag, pob.write(), true))
				showTagInfo(pob);

			SprFile spr = readTag!(SprFile)(tag);

			if (spr)
			{
				foreach (uint sprCount, ref sprtag; spr.tags)
					testTag(count, sprCount, sprtag, swfver);

				if (replaceTagData(tag, spr.write(), true))
					showTagInfo(spr);
			}

			readAndReplaceTag!(SymFile)();
		}
		catch (Exception e)
		{
			showTagInfo(e.msg, true);
			throw e;
		}
	}

	void testSwf(string swfName, string outputExt)
	{
		SWFFile swf = SWFFile.read(cast(ubyte[])read(swfName));

		foreach (uint count, ref tag; swf.tags)
			testTag(count, 0, tag, swf.header.ver);

		std.file.write(swfName ~ "." ~ outputExt, swf.write());
	}
}
