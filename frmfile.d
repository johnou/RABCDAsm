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

module frmfile;

import std.string : format;
import std.exception;

import swffile;
import tagreader;
import tagwriter;

final class FrmFile
{
	string frameLabel;
	bool hasAnchor = false;

	static bool isTagType(ref SWFFile.Tag tag)
	{
		return tag.type == TagType.FrameLabel;
	}

	static ubyte[] getTagData(ref SWFFile.Tag tag)
	{
		return tag.data;
	}

	static FrmFile read(ubyte[] data)
	{
		return (new FrmReader(data)).frm;
	}

	ubyte[] write()
	{
		return (new FrmWriter(this)).buf;
	}
}

private final class FrmReader : TagReader
{
	FrmFile frm;

	this(ubyte[] buf)
	{
		try
		{
			super(buf);
			frm = new FrmFile();
			frm.frameLabel = readStringZ();
			if (pos != buf.length)
			{
				frm.hasAnchor = true;
				enforce(readU8() == 1, "Invalid anchor flag in frame label");
			}
			enforce(pos == buf.length, "Invalid data");
		}
		catch (Exception e)
			throw new Exception(format("Error at %d (0x%X):", pos, pos), e);
	}
}

private final class FrmWriter : TagWriter
{
	FrmFile frm;

	this(FrmFile frm)
	{
		this.frm = frm;

		writeStringZ(frm.frameLabel);
		if (frm.hasAnchor)
			writeU8(1);

		buf.length = pos;
	}
}

