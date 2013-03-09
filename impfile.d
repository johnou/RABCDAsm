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

module impfile;

import std.string : format;
import std.exception;

import swffile;
import tagreader;
import tagwriter;

final class ImpFile
{
	Asset[] assets;

	struct Asset
	{
		ushort idref;
		string name;
	}

	static bool isTagType(ref SWFFile.Tag tag)
	{
		return tag.type == TagType.ImportAssets;
	}

	static ubyte[] getTagData(ref SWFFile.Tag tag)
	{
		return tag.data;
	}

	static ImpFile read(ubyte[] data)
	{
		return (new ImpReader(data)).imp;
	}

	ubyte[] write()
	{
		return (new ImpWriter(this)).buf;
	}
}

private final class ImpReader : TagReader
{
	ImpFile imp;

	this(ubyte[] buf)
	{
		try
		{
			super(buf);
			imp = new ImpFile();

			static uint atLeastOne(uint n)
			{
				return n ? n : 1;
			}

			imp.assets.length = atLeastOne(readU16());
			foreach (ref value; imp.assets[0..$])
				value = readAsset();
		}
		catch (Exception e)
			throw new Exception(format("Error at %d (0x%X):", pos, pos), e);
	}

	ImpFile.Asset readAsset()
	{
		ImpFile.Asset a;
		a.idref = readU16();
		a.name = readStringZ();
		return a;
	}
}

private final class ImpWriter : TagWriter
{
	ImpFile imp;

	this(ImpFile imp)
	{
		this.imp = imp;

		writeU16(cast(ushort)imp.assets.length);

		foreach(asset; imp.assets)
		{
			writeU16(asset.idref);
			writeStringZ(asset.name);
		}

		buf.length = pos;
	}
}

