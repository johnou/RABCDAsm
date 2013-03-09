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

module sprfile;

import std.string : format;
import std.exception;

import swffile;
import tagreader;
import tagwriter;

final class SprFile
{
	ushort spriteId;
	ushort frameCount;
	SWFFile.Tag[] tags;

	static bool isTagType(ref SWFFile.Tag tag)
	{
		return tag.type == TagType.DefineSprite;
	}

	static ubyte[] getTagData(ref SWFFile.Tag tag)
	{
		return tag.data;
	}

	static SprFile read(ubyte[] data)
	{
		return (new SprReader(data)).spr;
	}

	ubyte[] write()
	{
		return (new SprWriter(this)).buf;
	}
}

private final class SprReader : TagReader
{
	SprFile spr;

	this(ubyte[] buf)
	{
		try
		{
			super(buf);
			spr = new SprFile();

			spr.spriteId = readU16();
			spr.frameCount = readU16();

			while (pos < buf.length)
				spr.tags ~= readTag();

			enforce(pos == buf.length, "Invalid data");
		}
		catch (Exception e)
			throw new Exception(format("Error at %d (0x%X):", pos, pos), e);
	}
}

private final class SprWriter : TagWriter
{
	SprFile spr;

	this(SprFile spr)
	{
		this.spr = spr;

		writeU16(spr.spriteId);
		writeU16(spr.frameCount);

		foreach (ref tag; spr.tags)
			writeTag(tag);

		buf.length = pos;
	}
}

