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

module tagutils;

import std.ascii;
import std.digest.md;
import std.exception;
import std.regex;
import std.stdio;
import std.string : format;

import swffile;
import tagoptions;

ubyte minBits(uint number, bool signed)
{
	if (number == 0) // ignore signed
		return 0;

	ubyte bits = signed ? 1 : 0;

	for (; number > 0 && bits < 33; number >>= 1)
		++bits;

	enforce(bits < 33, format("minBits %d must not exceed 32", bits));

	return bits;
}

uint maxNum(int a, int b, int c, int d)
{
	int abs(int n) { enforce(n > int.min, "Unsupported abs(int.min)!"); return n < 0 ? -n : n; }
	int max(int n, int m) { return n < m ? m : n; }

	return cast(uint)max(abs(a), max(abs(b), max(abs(c), abs(d))));
}

T readTag(T)(ref SWFFile.Tag tag)
{
	if (T.isTagType(tag))
		return T.read(T.getTagData(tag));

	return null;
}

T readTagOptions(T)(ref SWFFile.Tag tag, ref TagOptions tagOptions)
{
	if (T.isTagType(tag))
		return T.read(cast(TagType)tag.type, T.getTagData(tag), tagOptions);

	return null;
}

string getPrintableEscapeString(T)(ref T s, uint maxLength = 0)
{
	string r = "";

	foreach(n, c; s)
	{
		r ~= isPrintable(c) ? "" ~ c : format("\\x%02X", c);
		if (maxLength && n >= maxLength - 1)
		{
			r ~= "... ";
			break;
		}
	}

	return r;
}

string getHexString(T)(ref T s, uint maxLength = 16)
{
	string r = "";

	foreach(n, c; s)
	{
		r ~= format("%02X ", c);
		if (maxLength && n >= maxLength - 1)
		{
			r ~= "... ";
			break;
		}
	}

	return r;
}

string getHexDumpString(T)(ref T s, string prefix = "", bool withAddress = true, bool withPrintable = true, uint bytesPerLine = 16)
{
	string r = "";
	string p = "";
	uint n = 0;

	foreach(c; s)
	{
		if (n % bytesPerLine == 0)
		{
			if (n)
			{
				r ~= p ~ "\n";
				p = "";
			}

			r ~= prefix ~ ": " ~ (withAddress ? format("%08X ", n) : "");
		}

		r ~= format("%02X ", c);

		if (withPrintable)
			p ~= isPrintable(c) ? c : '.';

		++n;
	}

	while (n++ % bytesPerLine)
		r ~= "   ";

	return r ~ p;
}

bool replaceTagData(ref SWFFile.Tag tag, ubyte[] data, bool showChanges)
{
	ubyte[] d1 = tag.data;
	ubyte[] m1 = md5Of(d1);

	if (tag.type == TagType.DoABC2)
	{
		auto p = tag.data.ptr+4; // skip flags
		while (*p++) {} // skip name
		tag.data = tag.data[0..p-tag.data.ptr] ~ data;
	}
	else
		tag.data = data;

	ubyte[] d2 = tag.data;
	ubyte[] m2 = md5Of(d2);

	const bool changed = m1 != m2;

	if (changed && showChanges)
	{
		writefln("TAG: %d => %d", tag.length, tag.data.length);

		writeln("TAG: s1");
		writeln(getHexDumpString(d1, "TAG"));
		writeln("TAG: s2");
		writeln(getHexDumpString(d2, "TAG"));
	}

	tag.length = cast(uint)tag.data.length;

	return changed;
}

bool isUrl(string s)
{
	static Regex!char url = regex("^(http[s]?|ftp[s]?|mailto|news|irc|gopher|nntp|feed|telnet|mms|rtsp|svn):");

	return !match(s, url).empty;
}
