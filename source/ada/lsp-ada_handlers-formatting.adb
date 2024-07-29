------------------------------------------------------------------------------
--                         Language Server Protocol                         --
--                                                                          --
--                     Copyright (C) 2018-2023, AdaCore                     --
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

with GNATCOLL.Traces;

with Pp.Command_Lines;
with Utils.Command_Lines;

with LSP.Enumerations;

package body LSP.Ada_Handlers.Formatting is

   Formatting_Trace : constant GNATCOLL.Traces.Trace_Handle :=
     GNATCOLL.Traces.Create ("ALS.FORMATTING", GNATCOLL.Traces.On);

   Gnatformat_Trace : constant GNATCOLL.Traces.Trace_Handle :=
     GNATCOLL.Traces.Create ("ALS.GNATFORMAT", GNATCOLL.Traces.Off);

   procedure Update_Pp_Formatting_Options
     (Pp_Options  : in out Utils.Command_Lines.Command_Line;
      LSP_Options : LSP.Structures.FormattingOptions);
   --  Update the gnatpp formatting options using the LSP ones.
   --  Options that are explicitly specified in the .gpr file take precedence
   --  over LSP options.

   ------------
   -- Format --
   ------------

   procedure Format
     (Context  : LSP.Ada_Contexts.Context;
      Document : not null LSP.Ada_Documents.Document_Access;
      Span     : LSP.Structures.A_Range;
      Options  : LSP.Structures.FormattingOptions;
      Success  : out Boolean;
      Response : out LSP.Structures.TextEdit_Vector;
      Messages : out VSS.String_Vectors.Virtual_String_Vector;
      Error    : out LSP.Errors.ResponseError)
   is
      procedure Gnatpp_Format;

      procedure Gnatformat_Format;

      -------------------
      -- Gnatpp_Format --
      -------------------

      procedure Gnatpp_Format
      is
         PP_Options : Utils.Command_Lines.Command_Line :=
           Context.Get_PP_Options;

      begin
         --  Take into account the options set by the request only if the
         --  corresponding GPR switches are not explicitly set.

         Update_Pp_Formatting_Options
           (Pp_Options => PP_Options, LSP_Options => Options);

         Success := Document.Formatting
           (Context  => Context,
            Span     => Span,
            Cmd      => PP_Options,
            Edit     => Response,
            Messages => Messages);

         if not Success then
            Error :=
              (code    => LSP.Enumerations.InternalError,
               message => Messages.Join (' '));
            Messages.Clear;
         end if;
      end Gnatpp_Format;

      -----------------------
      -- Gnatformat_Format --
      -----------------------

      procedure Gnatformat_Format
      is
      begin
         Success := True;
         Response := Document.Format (Context);

      exception
         when E : others =>
            Context.Tracer.Trace_Exception (E, "in GNATformat Format");
            Success := False;
            Error :=
              (code    => LSP.Enumerations.InternalError,
               message => "GNATformat failed to format source");
      end Gnatformat_Format;

   begin
      if Document.Has_Diagnostics (Context) then
         Success := False;
         Error   :=
           (code    => LSP.Enumerations.InternalError,
            message => "Incorrect code can't be formatted");

         return;
      end if;

      if Gnatformat_Trace.Is_Active then
         Gnatformat_Format;

      else
         Gnatpp_Format;
      end if;
   end Format;

   ------------------
   -- Range_Format --
   ------------------

   procedure Range_Format
     (Context  : LSP.Ada_Contexts.Context;
      Document : not null LSP.Ada_Documents.Document_Access;
      Span     : LSP.Structures.A_Range;
      Options  : LSP.Structures.FormattingOptions;
      Success  : out Boolean;
      Response : out LSP.Structures.TextEdit_Vector;
      Error    : out LSP.Errors.ResponseError)
   is
      procedure Gnatpp_Range_Format;

      procedure Gnatformat_Range_Format;

      -------------------------
      -- Gnatpp_Range_Format --
      -------------------------

      procedure Gnatpp_Range_Format
      is
         PP_Options : Utils.Command_Lines.Command_Line :=
           Context.Get_PP_Options;
         Messages   : VSS.String_Vectors.Virtual_String_Vector;

      begin
         --  Take into account the options set by the request only if the
         --  corresponding GPR switches are not explicitly set.

         Update_Pp_Formatting_Options
           (Pp_Options => PP_Options, LSP_Options => Options);

         Success := Document.Range_Formatting
           (Context    => Context,
            Span       => Span,
            PP_Options => PP_Options,
            Edit       => Response,
            Messages   => Messages);

         if not Success then
            Error :=
              (code    => LSP.Enumerations.InternalError,
               message => Messages.Join (' '));
         end if;
         if Document.Has_Diagnostics (Context) then
            Success := False;
            Error   :=
              (code    => LSP.Enumerations.InternalError,
               message => "Incorrect code can't be formatted");

            return;
         end if;
      end Gnatpp_Range_Format;

      ----------------------------
      -- Gnatformat_Range_Format --
      -----------------------------

      procedure Gnatformat_Range_Format
      is
      begin
         Success := True;
         Response.Clear;
         Response.Append (Document.Range_Format (Context, Span));

      exception
         when E : others =>
            Context.Tracer.Trace_Exception (E, "in GNATformat Range_Format");
            Success := False;
            Error :=
              (code    => LSP.Enumerations.InternalError,
               message => "GNATformat failed to format source");
      end Gnatformat_Range_Format;

   begin
      if Document.Has_Diagnostics (Context) then
         Success := False;
         Error   :=
           (code    => LSP.Enumerations.InternalError,
            message => "Syntactically incorrect code can't be formatted");

         return;
      end if;

      if Gnatformat_Trace.Is_Active then
         Gnatformat_Range_Format;

      else
         Gnatpp_Range_Format;
      end if;
   end Range_Format;

   ----------------------------------
   -- Update_Pp_Formatting_Options --
   ----------------------------------

   procedure Update_Pp_Formatting_Options
     (Pp_Options  : in out Utils.Command_Lines.Command_Line;
      LSP_Options : LSP.Structures.FormattingOptions)
   is
      Pp_Indentation : constant Natural :=
        Pp.Command_Lines.Pp_Nat_Switches.Arg
          (Pp_Options, Pp.Command_Lines.Indentation);
      Pp_No_Tab      : constant Boolean :=
        Pp.Command_Lines.Pp_Flag_Switches.Arg
          (Pp_Options, Pp.Command_Lines.No_Tab);

   begin
      --  Check if intentation and 'no tab' policy options have been explictly
      --  set in the project.
      --  If it's not the case, use the LSP options.

      if not Pp.Command_Lines.Pp_Nat_Switches.Explicit
        (Pp_Options, Pp.Command_Lines.Indentation)
      then
         Pp.Command_Lines.Pp_Nat_Switches.Set_Arg
           (Pp_Options,
            Pp.Command_Lines.Indentation,
            LSP_Options.tabSize);

      elsif Pp_Indentation /= LSP_Options.tabSize then
         Formatting_Trace.Trace
           ("Project file defines an indentation "
            & "of" & Pp_Indentation'Img & ", while LSP defines an "
            & "indentation of" & LSP_Options.tabSize'Img & ".");
      end if;

      if not Pp.Command_Lines.Pp_Flag_Switches.Explicit
        (Pp_Options, Pp.Command_Lines.No_Tab)
      then
         Pp.Command_Lines.Pp_Flag_Switches.Set_Arg
           (Pp_Options,
            Pp.Command_Lines.No_Tab,
            LSP_Options.insertSpaces);

      elsif Pp_No_Tab /= LSP_Options.insertSpaces then
         Formatting_Trace.Trace
           ("Project file no tab policy is set to " & Pp_No_Tab'Img
            & ", while LSP is set to " & LSP_Options.insertSpaces'Img);
      end if;
   end Update_Pp_Formatting_Options;

end LSP.Ada_Handlers.Formatting;
