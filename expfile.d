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

module expfile;

import std.string : format;
import std.exception;

import swffile;
import tagreader;
import tagwriter;

final class ExpFile
{
	Asset[] assets;

	struct Asset
	{
		ushort idref;
		string name;
	}

	static bool isTagType(ref SWFFile.Tag tag)
	{
		return tag.type == TagType.ExportAssets;
	}

	static ubyte[] getTagData(ref SWFFile.Tag tag)
	{
		return tag.data;
	}

	static ExpFile read(ubyte[] data)
	{
		return (new ExpReader(data)).exp;
	}

	ubyte[] write()
	{
		return (new ExpWriter(this)).buf;
	}
}

private final class ExpReader : TagReader
{
	ExpFile exp;

	this(ubyte[] buf)
	{
		try
		{
			super(buf);
			exp = new ExpFile();

			static uint atLeastOne(uint n)
			{
				return n ? n : 1;
			}

			exp.assets.length = atLeastOne(readU16());
			foreach (ref value; exp.assets[0..$])
				value = readAsset();
		}
		catch (Exception e)
			throw new Exception(format("Error at %d (0x%X):", pos, pos), e);
	}

	ExpFile.Asset readAsset()
	{
		ExpFile.Asset a;
		a.idref = readU16();
		a.name = readStringZ();
		return a;
	}
}

private final class ExpWriter : TagWriter
{
	ExpFile exp;

	this(ExpFile exp)
	{
		this.exp = exp;

		writeU16(cast(ushort)exp.assets.length);

		foreach(asset; exp.assets)
		{
			writeU16(asset.idref);
			writeStringZ(asset.name);
		}

		buf.length = pos;
	}
}

