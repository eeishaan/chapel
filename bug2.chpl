proc f1():int{
	writeln('H');
	return 2;
}
proc f2():int{
	writeln('H1');
	return 1;
}

proc main(){
	// var ans = begin f1()+ begin f2();
	var temp1$: single bool;
	var temp2$ : single bool;

	var retval1:int;
	var retval2:int;
	// proc f11(temp1$:bool,retval1:int){
	proc f11(retval1:int ){
		// retval1 = f1();
		// temp1$=true;
		return (true,f1());
	};
	// proc f22(temp2$:bool,retval2:int){
	proc f22(retval2:int){
		// retval2 = f2();
		return (true,f2());
		// temp2$=true;
	};
	// begin f11(temp1$,retval1);
	// begin f22(temp2$,retval2);
	// begin temp1$ = f11(retval1);
	begin (temp1$,retval1) = f11(retval1);
	begin (temp2$,retval2) = f22(retval2);

	var temp3$ = temp2$ && temp1$ ;
	var ans = retval2+retval1;





	writeln(ans);
}