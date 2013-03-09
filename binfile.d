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

module binfile;

import std.string : format;
import std.exception;

import swffile;
import tagreader;
import tagwriter;

final class BinFile
{
	ushort characterId;
	ubyte[] binaryData;

	static bool isTagType(ref SWFFile.Tag tag)
	{
		return tag.type == TagType.DefineBinaryData;
	}

	static ubyte[] getTagData(ref SWFFile.Tag tag)
	{
		return tag.data;
	}

	static BinFile read(ubyte[] data)
	{
		return (new BinReader(data)).bin;
	}

	ubyte[] write()
	{
		return (new BinWriter(this)).buf;
	}
}

private final class BinReader : TagReader
{
	BinFile bin;

	this(ubyte[] buf)
	{
		try
		{
			super(buf);
			bin = new BinFile();

			bin.characterId = readU16();

			enforce(readU32() == 0, "Invalid reserved data");

			bin.binaryData = cast(ubyte[])readArray(buf.length - pos);

			enforce(pos == buf.length, "Invalid data");
		}
		catch (Exception e)
			throw new Exception(format("Error at %d (0x%X):", pos, pos), e);
	}
}

private final class BinWriter : TagWriter
{
	BinFile bin;

	this(BinFile bin)
	{
		this.bin = bin;

		writeU16(bin.characterId);

		writeU32(0);

		writeBytes(bin.binaryData);

		buf.length = pos;
	}
}

