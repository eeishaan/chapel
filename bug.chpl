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
	begin temp1$ =  lambda(retval1):bool{
		// retval1 = f1();
		// temp2$=true;
		return true;
	};
	begin temp2$ = lambda(retval2):bool{
		// retval2 = f2();
		// temp2$=true;
		return true;
	};
	var temp3$ = temp2$ && temp1$ ;
	var ans = retval2+retval1;





	writeln(ans);
}