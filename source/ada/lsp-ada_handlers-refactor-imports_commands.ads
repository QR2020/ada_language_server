------------------------------------------------------------------------------
--                         Language Server Protocol                         --
--                                                                          --
--                     Copyright (C) 2020-2020, AdaCore                     --
--                                                                          --
-- This is free software;  you can redistribute it  and/or modify it  under --
-- terms of the  GNU General Public License as published  by the Free Soft- --
-- ware  Foundation;  either version 3,  or (at your option) any later ver- --
-- sion.  This software is distributed in the hope  that it will be useful, --
-- but WITHOUT ANY WARRANTY;  without even the implied warranty of MERCHAN- --
-- TABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public --
-- License for  more details.  You should have  received  a copy of the GNU --
-- General  Public  License  distributed  with  this  software;   see  file --
-- COPYING3.  If not, go to http://www.gnu.org/licenses for a complete copy --
-- of the license.                                                          --
------------------------------------------------------------------------------
--
--  Implementation of the command to refactor imports.

with Ada.Streams;

with VSS.Strings;

with LAL_Refactor;
with LAL_Refactor.Refactor_Imports;

with LSP.Client_Message_Receivers;
with LSP.JSON_Streams;

package LSP.Ada_Handlers.Refactor.Imports_Commands is

   type Command is new LSP.Ada_Handlers.Refactor.Command with private;

   overriding function Name (Self : Command) return String
   is
      ("Imports Command");

   procedure Initialize
     (Self         : in out Command'Class;
      Context      : LSP.Ada_Contexts.Context;
      Where        : LSP.Messages.TextDocumentPositionParams;
      With_Clause  : VSS.Strings.Virtual_String;
      Prefix       : VSS.Strings.Virtual_String);
   --  Initializes Command

   procedure Append_Suggestion
     (Self              : in out Command;
      Context           : Context_Access;
      Where             : LSP.Messages.Location;
      Commands_Vector   : in out LSP.Messages.CodeAction_Vector;
      Suggestion        : LAL_Refactor.Refactor_Imports.Import_Suggestion);
   --  Initializes Command based on Suggestion and appends it to
   --  Commands_Vector.

private

   type Command is new LSP.Ada_Handlers.Refactor.Command with record
      Context      : VSS.Strings.Virtual_String;
      Where        : LSP.Messages.TextDocumentPositionParams;
      With_Clause  : VSS.Strings.Virtual_String;
      Prefix       : VSS.Strings.Virtual_String;
   end record;

   overriding function Create
     (JS : not null access LSP.JSON_Streams.JSON_Stream'Class)
      return Command;

   overriding procedure Refactor
     (Self    : Command;
      Handler : not null access
        LSP.Server_Notification_Receivers.Server_Notification_Receiver'Class;
      Client  : not null access
        LSP.Client_Message_Receivers.Client_Message_Receiver'Class;
      Edits   : out LAL_Refactor.Refactoring_Edits);

   procedure Write_Command
     (S : access Ada.Streams.Root_Stream_Type'Class;
      V : Command);
   --  Write the command in a JSON Stream

   function Command_To_Refactoring_Edits
     (Self     : Command;
      Context  : LSP.Ada_Contexts.Context;
      Document : LSP.Ada_Documents.Document_Access)
      return LAL_Refactor.Refactoring_Edits;
   --  Converts Self into LAL_Refactor.Refactoring_Edits that can be
   --  converted in a WorkspaceEdit.

   for Command'Write use Write_Command;
   for Command'External_Tag use "als-refactor-imports";

end LSP.Ada_Handlers.Refactor.Imports_Commands;
