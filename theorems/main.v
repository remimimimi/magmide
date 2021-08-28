Add LoadPath "/home/blaine/lab/cpdtlib" as Cpdt.
Set Implicit Arguments. Set Asymmetric Patterns.
Require Import List String Cpdt.CpdtTactics Coq.Program.Wf.
From stdpp Require Import base fin vector options.
Import ListNotations.
Require Import theorems.utils.

Example test__vec_total_lookup: ([# 4; 2] !!! 0%fin) = 4.
Proof. reflexivity. Qed.

Section Sized.
	Variable size: nat.
	Notation RegisterBank := (vec nat size).
	Notation register := (fin size).

	Inductive Operand: Type :=
		| Literal (n: nat)
		| Register (r: register)
	.

	Definition eval_operand
		(bank: RegisterBank) (operand: Operand)
	: nat :=
		match operand with
		| Literal n => n
		| Register r => (bank !!! r)
		end
	.

	Inductive Instruction :=
		| InstExit
		| InstMov (src: Operand) (dest: register)
		| InstAdd (val: Operand) (dest: register)

		(*| InstJump (to: string)*)
		(*| InstBranchEq (a: Operand) (b: Operand) (to: string)*)
		(*| InstBranchNeq (a: Operand) (b: Operand) (to: string)*)

		(*| InstStore (src: Operand) (dest: Operand)*)
		(*| InstLoad (src: Operand) (dest: register)*)
	.
	Hint Constructors Instruction: core.

	Record MachineState := state {
		counter: nat;
		registers: RegisterBank
	}.
	Notation Within program cur :=
		(cur.(counter) < (length program)) (only parsing).

	Notation cur_instr cur program :=
		(lookup cur.(counter) program) (only parsing).

	Notation get_instr cur program :=
		(@safe_lookup _ cur.(counter) program _) (only parsing).

	Notation eval cur val :=
		(eval_operand cur.(registers) val) (only parsing).

	Notation get cur reg :=
		(cur.(registers) !!! reg) (only parsing).

	Notation update cur dest val :=
		(vinsert dest val cur.(registers)) (only parsing).

	Notation incr cur :=
		(S cur.(counter)) (only parsing).

	Inductive step
		{program: list Instruction}
	: MachineState -> MachineState -> Prop :=
		| step_Mov: forall cur src dest,
			(cur_instr cur program) = Some (InstMov src dest)
			-> step cur (state
				(incr cur)
				(update cur dest (eval cur src))
			)

		| step_Add: forall cur val dest,
			(cur_instr cur program) = Some (InstAdd val dest)
			-> step cur (state
				(incr cur)
				(update cur dest ((eval cur val) + (get cur dest)))
			)

		(*| step_Jump: forall cur to,
			(cur_instr cur program) = Some (InstJump to)
			-> exists next, find_label program to = Some next
			-> step next bank*)

		(*| step_BranchEq_Eq: forall cur a b to,
			(cur_instr cur program) = Some (InstBranchEq a b to)
			-> a = b
			-> exists next, find_label program to = Some next
			-> step next bank
		| step_BranchEq_Neq: forall cur a b to,
			(cur_instr cur program) = Some (InstBranchEq a b to)
			-> a <> b
			-> step (S cur) bank*)

		(*| step_BranchNeq_Neq: forall cur a b to,
			(cur_instr cur program) = Some (InstBranchNeq Ne b to)
			-> a <> b
			-> exists next, find_label program to = Some next
			-> step next bank
		| step_BranchNeq_Eq: forall cur a b to,
			(cur_instr cur program) = Some (InstBranchNeq Ne b to)
			-> a = b
			-> step (S cur) bank*)
	.
	Hint Constructors step: core.

	(*Inductive step_trace program: forall cur next, (list @step program cur next) -> Prop :=
		| trace_Exit: forall cur next,
			@step program cur next
			-> (cur_instr next program) = Some InstExit
			-> trace program cur next [@step program cur next]
		| trace_Step
	.*)

	Theorem step_always_Within program cur next:
		@step program cur next -> Within program cur.
	Proof.
		inversion 1;
		match goal with
		| H: _ !! counter _ = Some _ |- _ =>
			apply lookup_lt_Some in H; assumption
		end.
	Qed.

	Inductive branching: Instruction -> Prop :=
		(*| branch_BranchEq: forall a b to, branching (InstBranchEq a b to)*)
		(*| branch_BranchNeq: forall a b to, branching (InstBranchNeq a b to)*)
		(*| branch_Jump: forall to, branching (InstJump to)*)
	.
	Hint Constructors branching: core.

	Inductive stopping: Instruction -> Prop :=
		| stopping_Exit: stopping InstExit
	.
	Hint Constructors stopping: core.

	Definition is_stopping: forall instr, {stopping instr} + {~(stopping instr)}.
		refine (fun instr =>
			match instr with | InstExit => Yes | _ => No end
		); try constructor; inversion 1.
	Defined.

	Theorem stopping_stuck instr:
		stopping instr
		-> forall program cur next,
		(cur_instr cur program) = Some instr
		-> ~(@step program cur next).
	Proof.
		intros Hstopping ???? Hstep;
		inversion Hstopping; inversion Hstep; crush.
	Qed.

	Theorem not_stopping_not_stuck instr:
		~(stopping instr)
		-> forall program cur,
		(cur_instr cur program) = Some instr
		-> exists next, @step program cur next.
	Proof.
		destruct instr; try contradiction; eauto.
	Qed.

	Notation NextStep program instr cur next :=
		((cur_instr cur (program%list)) = Some instr -> @step (program%list) cur next)
		(only parsing).

	Definition execute_instruction:
		forall instr (cur: MachineState), ~stopping instr
		-> {next: MachineState | forall program, NextStep program instr cur next}
	.
		refine (fun instr cur =>
			match instr with
			| InstMov src dest => fun _ => this (state
				(incr cur)
				(update cur dest (eval cur src))
			)
			| InstAdd val dest => fun _ => this (state
				(incr cur)
				(update cur dest ((eval cur val) + (get cur dest)))
			)
			| _ => fun _ => impossible
			end
		); destruct instr; try contradiction; auto.
	Defined.

	Definition execute_program_unsafe
		(program: list Instruction)
	:
		nat -> MachineState -> option MachineState
	.
		refine (fix go steps cur :=
			match (cur_instr cur program) with
			| None => None
			| Some instr =>
				if (is_stopping instr) then Some cur
				else match steps with
				| 0 => None
				| S steps' =>
					let (next, _) := (@execute_instruction instr cur _) in
					go steps' next
				end
			end
		); assumption.
	Defined.

	Notation WellFormed program :=
		(forall cur next, @step program cur next -> Within program next).

	Definition check_instruction_well_formed index len_program: forall instr, partial (
		forall program cur next,
		(lookup index program) = Some instr
		-> @step program cur next
		-> cur.(counter) = index
		-> len_program <= (length program)
		-> Within program next
	).
		refine (fun instr =>
			if (is_stopping instr) then found
			else if (lt_dec (S index) len_program) then found else notfound
			(*if (is_sequential instr)*)
		);
		intros ??? Hsome Hstep ??; subst;
		try apply (stopping_stuck s Hsome) in Hstep;
		destruct instr; inversion Hstep; try contradiction; simpl in *; subst; lia.
	Defined.


	Definition check_program_well_formed program :=
		find_obligations (fun instr => ) (check_instruction_well_formed)
		check_program_well_formed

	Definition check_program_well_formed: list Instruction -> partial (WellFormed program).
		refine (fun program =>
			let len_program := (length program) in
			(fix go program len_program :=
			match program with
			| [] => Yes
			| instr :: program' =>
				if (is_stopping instr) then go program' len_program
				else
			end) program len_program
		).
	Defined.

	Ltac program_well_formed :=
		match goal with
		| |- WellFormed ?program => exact (partialOut (check_program_well_formed program))
		end.

	Definition execute_program_unknown_termination
		(program: list Instruction)
		(well_formed: WellFormed program)
	:
		nat -> forall cur, Within program cur -> option MachineState
	.
		refine (fix go steps cur _ :=
			let (instr, _) := (get_instr cur program) in
			if (is_stopping instr) then Some cur
			else match steps with
			| 0 => None
			| S steps' =>
				let (next, _) := (@execute_instruction instr cur _) in
				go steps' next _
			end
		); eauto.
	Defined.

	Section execute_program.
		Variable program: list Instruction.
		Variable well_formed: WellFormed program.
		Variable progress: MachineState -> MachineState -> Prop.
		Variable progress_wf: well_founded progress.
		Variable program_progress:
			forall cur next, @step program cur next -> progress next cur.

		Program Fixpoint execute_program
			cur (H: Within program cur) {wf progress cur}
		: MachineState :=
			let (instr, _) := (get_instr cur program) in
			if (is_stopping instr) then cur
			else
				let (next, _) := (@execute_instruction instr cur _) in
				execute_program next _
		.
		Solve All Obligations with eauto.
	End execute_program.

	(*
	The really important thing is the sequential list of instructions can have anything appended to it, but as long as it's something non empty the sequential block is safe to execute
	It's probably a good idea to create a prop as the opposite of branching for all the instructions that have a step but don't merely increment the counter

	basically I want to rethink this concept of sequential to be more in line with a basic block
	essentially that the purely sequential *portion* of a basic block is both safe and the step relation is well founded
	more work is required later in order to prove what happens *after* the sequential segment

	so I'm going to create a sequential prop that cateogorizes *instructions*, and then a "basic block" definitional prop that just says an entire list of instructions are sequential

	later we can add constructors to the sequential prop that apply to conditional branches, but only given that their branch condition is false
	*)

	Inductive sequential: list Instruction -> Prop :=
		| sequential_End: forall instr,
			stopping instr
			-> sequential [instr]

		| sequential_Cons: forall instr rest,
			(*~(branching instr)*)
			sequential rest
			-> sequential (instr :: rest)
	.
	Hint Constructors sequential: core.

	Theorem sequential_not_empty program:
		sequential program -> 0 < length program.
	Proof. inversion 1; crush. Qed.

	Theorem sequential_step_increments program cur next:
		sequential program
		-> @step program cur next
		-> next.(counter) = (incr cur).
	Proof.
		intros Hsequential Hstep;
		inversion Hsequential; inversion Hstep; crush.
	Qed.

	Theorem sequential_step_safe program cur next:
		sequential program
		-> @step program cur next
		-> Within program next.
	Proof.

		Qed.

	Theorem sequential_step_well_founded program:
		sequential program
		-> program_well_founded program.
	Proof.
	Qed.


	Theorem existent_not_stuck: forall program cur bank instr,
		(cur_instr cur program) = Some instr
		->
			stopping instr
			\/ exists cur' bank', @step program cur bank cur' bank'.
	Proof. intros ??? [] ?; eauto. Qed.

	Theorem terminated_wf: forall program,
		terminated program
		->
		-> well_founded (remaining)

	Theorem terminated_not_stuck: forall program,
		terminated program
		->

		(cur_instr cur program) = Some instr
		->
			stopping instr
			\/ exists next bank', @step program cur bank next bank'.
	Proof. intros ??? [] ?; eauto. Qed.

End Sized.

Arguments Literal {size} _.
Arguments Register {size} _.

Arguments execute_program_unsafe {size} _ _ _ _.

Arguments InstMov {size} _ _.
Arguments InstAdd {size} _ _.
(*Arguments InstBranchEq {size} _ _ _.*)
(*Arguments InstBranchNeq {size} _ _ _.*)
Arguments InstExit {size}.


Definition redundant_additions: list (Instruction 1) := [
	InstMov (Literal 0) (0%fin);
	InstAdd (Literal 1) (0%fin);
	InstAdd (Literal 1) (0%fin);
	InstAdd (Literal 1) (0%fin);
	InstAdd (Literal 1) (0%fin);
	InstAdd (Literal 1) (0%fin);
	InstExit
].
Example test__redundant_additions:
	execute_program_unsafe
		(length redundant_additions) redundant_additions 0 [#0] = Some [#5].
Proof. reflexivity. Qed.


Definition redundant_doubling: list (Instruction 1) := [
	InstMov (Literal 1) (0%fin);
	InstAdd (Register 0%fin) (0%fin);
	InstAdd (Register 0%fin) (0%fin);
	InstAdd (Register 0%fin) (0%fin);
	InstExit
].
Example test__redundant_doubling:
	execute_program_unsafe
		(length redundant_doubling) redundant_doubling 0 [#0] = Some [#8].
Proof. reflexivity. Qed.

(*
that can run a program to completion but can fail and requires fuel
then prove that a particular linear program can be run with a *safe* variant since it decreases on a well-founded order
then prove that any purely dag-like program can be run safely
then figure out how to prove that any labeled program that proof justifies cyclic jumps can be run safely
*)

(*
Definition mergeSort: list A -> list A.
refine (Fix lengthOrder wf (fun => list A)
	(fun
		(ls: list A)
		(mergeSort: forall ls': list A, lengthOrder ls' ls -> list A)
	=>
			if le_lt_dec 2 (length ls)
			then let lss := split ls in
			merge (mergeSort (fst lss)) (mergeSort (snd lss))
			else ls)
); subst lss; eauto.
Defined.
*)

Notation val := Operand (only parsing).
Notation expr := Instruction (only parsing).

Notation of_val := InstExit (only parsing).

Definition to_val (e: expr): option val :=
	match e with
	| InstExit _ v => Some v
	| _ => None
	end.

(*
	So the first program I'm interested in verifying is this one.
	I want to obviously verify it's safe and such, but also I want to be

main: (this label is implicit)
	{{ True }}
	Mov 0 $r1
	{{ $r1 = 0 }}
loop:
	{{ exists n < 10. $r1 = n }}
	Add 1 $r1
	{{ exists n <= 10. $r1 = n + 1}}
	BranchNeq $r1 10 loop
done:
	{{ $r1 = 10 }}
	Exit $r1

*)


Inductive Bit: Type := B0 | B1.




Inductive Result (T: Type) (E: Type): Type :=
	| Ok (value: T)
	| Err (error: E).

Arguments Ok {T} {E} _.
Arguments Err {T} {E} _.

