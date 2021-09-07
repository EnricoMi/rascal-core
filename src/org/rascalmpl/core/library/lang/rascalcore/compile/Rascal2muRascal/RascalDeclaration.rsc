@bootstrapParser
module lang::rascalcore::compile::Rascal2muRascal::RascalDeclaration

import IO;
import Map;
import List;
import ListRelation;
import Location;
import Set;
import String;
import lang::rascal::\syntax::Rascal;
import ParseTree;

import lang::rascalcore::compile::CompileTimeError;

import lang::rascalcore::compile::muRascal::AST;

import lang::rascalcore::check::AType;
import lang::rascalcore::check::ATypeUtils;
import lang::rascalcore::check::NameUtils;
import lang::rascalcore::compile::util::Names;
import lang::rascalcore::check::SyntaxGetters;

import lang::rascalcore::compile::Rascal2muRascal::ModuleInfo;
import lang::rascalcore::compile::Rascal2muRascal::RascalType;
import lang::rascalcore::compile::Rascal2muRascal::TypeUtils;
import lang::rascalcore::compile::Rascal2muRascal::TypeReifier;
import lang::rascalcore::compile::Rascal2muRascal::TmpAndLabel;

import lang::rascalcore::compile::Rascal2muRascal::RascalExpression;
import lang::rascalcore::compile::Rascal2muRascal::RascalPattern;
import lang::rascalcore::compile::Rascal2muRascal::RascalStatement;




/********************************************************************/
/*                  Translate declarations in a module              */
/********************************************************************/
	
void translate((Toplevel) `<Declaration decl>`) = translate(decl);

// -- variable declaration ------------------------------------------

void translate(d: (Declaration) `<Tags tags> <Visibility visibility> <Type tp> <{Variable ","}+ variables> ;`) {
	str module_name = getUnqualifiedName(getModuleName());
    ftype = afunc(avalue(),[avalue()], []);
    enterFunctionScope("<module_name>_init");
   	for(var <- variables){
   	    unescapedVarName = unescapeName("<var.name>");
   		addVariableToModule(muModuleVar(getType(tp), unescapedVarName));
   		//variables_in_module += [];
   		if(var is initialized) {
   		   init_code =  translate(var.initial);
   		   asg = muAssign( muVar(unescapedVarName, getModuleName(), -1, getType(tp)), init_code);
   		   addVariableInitializationToModule(asg);
   		}
   	}
   	leaveFunctionScope();
}   	

// -- miscellaneous declarations that can be skipped since they are handled during type checking ------------------

void translate(d: (Declaration) `<Tags tags> <Visibility visibility> anno <Type annoType> <Type onType>@<Name name> ;`) { /*skip: translation has nothing to do here */ }
void translate(d: (Declaration) `<Tags tags> <Visibility visibility> alias <UserType user> = <Type base> ;`)   { /* skip: translation has nothing to do here */ }
void translate(d: (Declaration) `<Tags tags> <Visibility visibility> tag <Kind kind> <Name name> on <{Type ","}+ types> ;`)  { throw("tag"); }

void translate(d : (Declaration) `<Tags tags> <Visibility visibility> data <UserType user> <CommonKeywordParameters commonKeywordParameters> ;`) { /* skip: translation has nothing to do here */ }


void translate(d: (Declaration) `<Tags tags> <Visibility visibility> data <UserType user> <CommonKeywordParameters commonKeywordParameters> = <{Variant "|"}+ variants> ;`) {
    /* all getters are generated by generateAllFieldGetters */
 }
 
 MuExp promoteVarsToFieldReferences(MuExp exp, AType consType, MuExp consVar)
    = visit(exp){
        case muVar(str fieldName, _, -1, AType tp)        => muGetField(tp, consType, consVar, fieldName)
        case muVarKwp(str fieldName, str scope, AType tp) => muGetKwField(tp, consType, consVar, fieldName, getModuleName())
     };
    
void translate(d: (Declaration) `<FunctionDeclaration functionDeclaration>`) = translate(functionDeclaration);


void generateAllFieldGetters(loc module_scope){
    map[AType, set[AType]] adt_constructors = getConstructorsMap();
    map[AType, list[Keyword]] adt_common_keyword_fields = getCommonKeywordFieldsMap();
    
    for(adtType <- getADTs(), !isSyntaxType(adtType)){
        generateGettersForAdt(adtType, module_scope, adt_constructors[adtType] ? {}, adt_common_keyword_fields[adtType] ? []);
    }
}

private void generateGettersForAdt(AType adtType, loc module_scope, set[AType] constructors, list[Keyword] common_keyword_fields){

    adtName = adtType.adtName;
    /*
     * Create getters for common keyword fields of this data type
     */
    seen = {};
    for(<kwType, defaultExp> <- common_keyword_fields, kwType notin seen, isContainedIn(defaultExp@\loc, module_scope)){
        seen += kwType;
        str kwFieldName = unescape(kwType.label);
        if(asubtype(adtType, treeType)){
            if(kwFieldName == "loc") kwFieldName = "src"; // TODO: remove when @\loc is gone
        }
        str fuid = getGetterNameForKwpField(adtType, kwFieldName);
        str getterName = unescapeAndStandardize("$getkw_<adtName>_<kwFieldName>");
       
        getterType = afunc(kwType, [adtType], []);
        adtVar = muVar(getterName, fuid, 0, adtType);
        
        defExprCode = promoteVarsToFieldReferences(translate(defaultExp), adtType, adtVar);
        body = muReturn1(kwType, muIfElse(muIsKwpDefined(adtVar, kwFieldName), muGetKwFieldFromConstructor(kwType, adtVar, kwFieldName), defExprCode));
        addFunctionToModule(muFunction(fuid, getterName, getterType, [adtVar], [], "", false, true, false, {}, {}, {}, getModuleScope(), [], (), body));               
    }
    
    /*
     * Create getters for constructor specific keyword fields.
     */
    
    kwfield2cons = [];
       
    for(consType <- constructors){
       /*
        * Create constructor=specific getters for each keyword field
        */
       consName = consType.label;
       
       for(<kwType, defaultExp> <- consType.kwFields, isContainedIn(defaultExp@\loc, module_scope)){
            str kwFieldName = kwType.label;
            kwfield2cons += <kwFieldName, kwType, consType>;
            str fuid = getGetterNameForKwpField(consType, kwFieldName);
            str getterName = unescapeAndStandardize("$getkw_<adtName>_<consName>_<kwFieldName>");
            
            getterType = afunc(kwType, [consType], []);
            consVar = muVar(consName, fuid, 0, consType);
            
            defExpCode = promoteVarsToFieldReferences(translate(defaultExp), consType, consVar);
            body = muReturn1(kwType, muIfElse(muIsKwpDefined(consVar, kwFieldName), muGetKwFieldFromConstructor(kwType, consVar, kwFieldName), defExpCode));
            addFunctionToModule(muFunction(fuid, getterName, getterType, [consVar], [], "", false, true, false, {}, {}, {}, getModuleScope(), [], (), body));               
       }
    }
    
     /*
      * Create generic getters for all keyword fields
      */
    
    for(str kwFieldName <- domain(kwfield2cons)){
        conses = kwfield2cons[kwFieldName];
        str fuid = getGetterNameForKwpField(adtType, kwFieldName);
        str getterName = unescapeAndStandardize("$getkw_<adtName>_<kwFieldName>");
            
        returnType = lubList(conses<0>);
        getterType = afunc(returnType, [adtType], []);
        adtVar = muVar(adtName, fuid, 0, adtType);
        body = muBlock([ muIf(muHasNameAndArity(adtType, consType, muCon(consType.label), size(consType.fields), adtVar),
                              muReturn1(kwType, muGetKwField(kwType, consType, adtVar, kwFieldName, findDefiningModule(getLoc(consType.kwFields[0].defaultExp)))))
                       | <kwType, consType> <- conses, isContainedIn(getLoc(consType.kwFields[0].defaultExp), module_scope)
                       ]
                       + muFailReturn(returnType)
                      );
        addFunctionToModule(muFunction(fuid, getterName, getterType, [adtVar], [], "", false, true, false, {}, {}, {}, getModuleScope(), [], (), body));               
    }
    
    /*
     * Ordinary fields are directly accessed via information in the constructor type
     */
 }


// -- function declaration ------------------------------------------

Expression dummy_body_expression = (Expression) `"dummy"`;

void translate(fd: (FunctionDeclaration) `<Tags tags> <Visibility visibility> <Signature signature> ;`)   {
  translateFunctionDeclaration(fd, [], dummy_body_expression, []);
}

void translate(fd: (FunctionDeclaration) `<Tags tags> <Visibility visibility> <Signature signature> = <Expression expression> ;`){
  translateFunctionDeclaration(fd, [], expression, [], addReturn=true);
}

void translate(fd: (FunctionDeclaration) `<Tags tags> <Visibility visibility> <Signature signature> = <Expression expression> when <{Expression ","}+ conditions>;`){
  translateFunctionDeclaration(fd, [], expression, [exp | exp <- conditions], addReturn=true); 
}

void translate(fd: (FunctionDeclaration) `<Tags tags>  <Visibility visibility> <Signature signature> <FunctionBody body>`){
  Expression exp = (Expression) `"dummy"`;
  translateFunctionDeclaration(fd, [stat | stat <- body.statements], dummy_body_expression, []);
}

set[TypeVar] getTypeVarsinFunction(FunctionDeclaration fd){
    trees = {};
    if(fd has body){
        trees = {fd.body};
    } else if(fd has expression){
        trees = fd has conditions ? {fd.expression, fd.conditions} : {fd.expression};
    }
    res = {};
    top-down-break visit(trees){
        case (Expression) `<Type \type> <Parameters parameters> { <Statement+ statements> }`:
                /* ignore type vars in closures. This is not water tight since a type parameter of the surrounding
                  function may be used in the body of this closure */;
        case TypeVar tv: res += tv;
    }
    return res;
}

private void translateFunctionDeclaration(FunctionDeclaration fd, list[Statement] body, Expression body_expression, list[Expression] when_conditions, bool addReturn = false){
  println("r2mu: Compiling \uE007[<fd.signature.name>](<fd@\loc>)");
  
  inScope = topFunctionScope();
  funsrc = fd@\loc;
  useTypeParams = getTypeVarsinFunction(fd);
  enterFunctionDeclaration(funsrc, !isEmpty(useTypeParams));

  try {
      ttags =  translateTags(fd.tags);
      tmods = translateModifiers(fd.signature.modifiers);
      if(ignoreTest(ttags)){
          // The type checker does not generate type information for ignored functions
           addFunctionToModule(muFunction("$ignored_<prettyPrintName(fd.signature.name)>_<fd@\loc.offset>", 
                                         prettyPrintName(fd.signature.name), 
                                         afunc(abool(),[],[]),
                                         [],
                                         [],
                                         inScope, 
                                         false, 
                                         true,
                                         false,
                                         {},
                                         {},
                                         {},
                                         fd@\loc, 
                                         tmods, 
                                         ttags,
                                         muReturn1(abool(), muCon(false))));
          	return;
      }
      fname = prettyPrintName(fd.signature.name);
      ftype = getFunctionType(funsrc);
      resultType = ftype.ret;
      bool isVarArgs = ftype.varArgs;
      nformals = size(ftype.formals);
      fuid = convert2fuid(funsrc);
    
      enterFunctionScope(fuid);
      
     
      
      //// Keyword parameters
      lrel[str name, AType atype, MuExp defaultExp]  kwps = translateKeywordParameters(fd.signature.parameters);
      
      my_btscopes = getBTScopesParams([ft | ft <- fd.signature.parameters.formals.formals], fname);
      mubody = muBlock([]);
      if(ttags["javaClass"]?){
         params = [ muVar(ftype.formals[i].label, fuid, i, ftype.formals[i]) | i <- [ 0 .. nformals] ];
         mubody = muReturn1(resultType, muCallJava("<fd.signature.name>", ttags["javaClass"], ftype, params, fuid));
      } else if(body_expression == dummy_body_expression){ // statements are present in body
          if(!isEmpty(body)){
                if(size(body) == 1 && addReturn){
                    mubody = translateReturn(getType(body[0]), body[0], my_btscopes);
                 } else {
                    mubody = muBlock([ translate(stat, my_btscopes) | stat <- body ]);
                 }
          }
       } else {
            mubody = addReturn ? translateReturn(getType(body_expression), body_expression) : translate(body_expression);
       }

      enterSignatureSection();
     
      isPub = !fd.visibility is \private;
      isMemo = ttags["memo"]?; 
      <formalVars, tbody> = translateFunction(fname, fd.signature.parameters.formals.formals, ftype, mubody, isMemo, when_conditions);
      
      typeVarsInParams = getFunctionTypeParameters(ftype);
      if(!isEmpty(useTypeParams)){
        tbody = muBlock([muTypeParameterMap(typeVarsInParams), tbody]);
      }
      
      leaveSignatureSection();
      addFunctionToModule(muFunction(prettyPrintName(fd.signature.name), 
                                     fuid, 
      								 ftype,
      								 formalVars,
      								 kwps,
      								 inScope,
      								 isVarArgs, 
      								 isPub,
      								 isMemo,
      								 getExternalRefs(tbody, fuid),
      								 getLocalRefs(tbody),
      								 getKeywordParameterRefs(tbody, fuid),
      								 fd@\loc, 
      								 tmods, 
      								 ttags,
      								 tbody));
      
      leaveFunctionScope();
      leaveFunctionDeclaration();
  } catch e: CompileTimeError(m): {
      throw e;  
  } catch Ambiguity(loc src, str stype, str string): {
      throw CompileTimeError(error("Ambiguous code", src));
  }
  //catch e: {
  //      throw "EXCEPTION in translateFunctionDeclaration, compiling <fd.signature.name>: <e>";
  //}
}

str getParameterName(list[Pattern] patterns, int i) = getParameterName(patterns[i], i);

str getParameterName((Pattern) `<QualifiedName qname>`, int i) = "<qname>";
str getParameterName((Pattern) `<QualifiedName qname> *`, int i) = "<qname>";
str getParameterName((Pattern) `<Type tp> <Name name>`, int i) = "<name>";
str getParameterName((Pattern) `<Name name> : <Pattern pattern>`, int i) = "<name>";
str getParameterName((Pattern) `<Type tp> <Name name> : <Pattern pattern>`, int i) = "<name>";
default str getParameterName(Pattern p, int i) = "$<i>";

list[str] getParameterNames({Pattern ","}* formals){
     abs_formals = [f | f <- formals];
     return[ getParameterName(abs_formals, i) | i <- index(abs_formals) ];
}

Tree getParameterNameAsTree(list[Pattern] patterns, int i) = getParameterNameAsTree(patterns[i], i);

Tree getParameterNameAsTree((Pattern) `<QualifiedName qname>`, int i) = qname;
Tree getParameterNameAsTree((Pattern) `<QualifiedName qname> *`, int i) = qname;
Tree getParameterNameAsTree((Pattern) `<Type tp> <Name name>`, int i) = name;
Tree getParameterNameAsTree((Pattern) `<Name name> : <Pattern pattern>`, int i) = name;
Tree getParameterNameAsTree((Pattern) `<Type tp> <Name name> : <Pattern pattern>`, int i) = name;

bool hasParameterName(list[Pattern] patterns, int i) = hasParameterName(patterns[i], i);

bool hasParameterName((Pattern) `<QualifiedName qname>`, int i) = "<qname>" != "_";
bool hasParameterName((Pattern) `<QualifiedName qname> *`, int i) = "<qname>" != "_";
bool hasParameterName((Pattern) `<Type tp> <Name name>`, int i) = "<name>" != "_";
bool hasParameterName((Pattern) `<Name name> : <Pattern pattern>`, int i) = "<name>" != "_";
bool hasParameterName((Pattern) `<Type tp> <Name name> : <Pattern pattern>`, int i) = "<name>" != "_";
default bool hasParameterName(Pattern p, int i) = false;

set[MuExp] getAssignedInVisit(list[MuCase] cases, MuExp def)
    = { v | exp <- [c.exp | c <- cases] + def, /muAssign(v:muVar(str name, str fuid2, int pos, AType atype), MuExp _) := exp};
    
set[MuExp] getLocalRefs(MuExp exp)
  = { *getAssignedInVisit(cases, defaultExp) | /muVisit(str _, MuExp _, list[MuCase] cases, MuExp defaultExp, VisitDescriptor _) := exp };

set[MuExp] getExternalRefs(MuExp exp, str fuid)
    = { v | /v:muVar(str name, str fuid2, int pos, AType atype) := exp, fuid2 != fuid, fuid2 != "" };

set[MuExp] getKeywordParameterRefs(MuExp exp, str fuid)
    = { v | /v:muVarKwp(str name, str fuid2, AType atype) := exp, fuid2 != fuid };
    
/********************************************************************/
/*                  Translate keyword parameters                    */
/********************************************************************/

lrel[str name, AType atype, MuExp defaultExp] translateKeywordParameters(Parameters parameters) {
  KeywordFormals kwfs = parameters.keywordFormals;
  kwmap = [];
  if(kwfs is \default && {KeywordFormal ","}+ keywordFormalList := parameters.keywordFormals.keywordFormalList){
      keywordParamsMap = getKeywords(parameters);
      kwmap = [ <"<kwf.name>", keywordParamsMap["<kwf.name>"], translate(kwf.expression)> | KeywordFormal kwf <- keywordFormalList ];
  }
  return kwmap;
}

/********************************************************************/
/*                  Translate function body                         */
/********************************************************************/

MuExp returnFromFunction(MuExp body, AType ftype, list[MuExp] formalVars, bool isMemo, bool addReturn=false) {
  if(ftype.ret == avoid()){ 
    res = body;
    if(isMemo){
         res = visit(res){
            case muReturn0() => muMemoReturn0(ftype, formalVars)
         }
         res = muBlock([res,  muMemoReturn0(ftype, formalVars)]);
      }
     return res;
  } else {
      res = addReturn ? muReturn1(ftype.ret, body) : body;
      if(isMemo){
         res = visit(res){
            case muReturn1(t, e) => muMemoReturn1(ftype, formalVars, e)
         }
      }
      return res;   
  }
}
         
MuExp functionBody(MuExp body, AType ftype, list[MuExp] formalVars, bool isMemo){
    if(isMemo){
        str fuid = topFunctionScope();
        result = muTmpIValue(nextTmp("result"), fuid, avalue());
        return muCheckMemo(ftype, formalVars, body);
    } else {
        return body;
    }
}

tuple[list[MuExp] formalVars, MuExp funBody] translateFunction(str fname, {Pattern ","}* formals, AType ftype, MuExp body, bool isMemo, list[Expression] when_conditions, bool addReturn=false){
     // Create a loop label to deal with potential backtracking induced by the formal parameter patterns  
     
     list[Pattern] formalsList = [f | f <- formals];
     str fuid = topFunctionScope();
     my_btscopes = getBTScopesParams(formalsList, fname);
     
     formalVars = [ hasParameterName(formalsList, i) && !isUse(formalsList[i]@\loc) ? muVar(pname, fuid, getPositionInScope(pname, getParameterNameAsTree(formalsList, i)@\loc), getType(formalsList[i]))
                                                                                    : muVar(pname, fuid, -i, getType(formalsList[i]))   
                  | i <- index(formalsList),  pname := getParameterName(formalsList, i) 
                  ];
     leaveSignatureSection();
     when_body = returnFromFunction(body, ftype, formalVars, isMemo, addReturn=addReturn);
     
     if(!isEmpty(when_conditions)){
        when_body = translateAndConds((), when_conditions, when_body, muFailReturn(ftype));
     }
     enterSignatureSection();
     params_when_body = ( when_body
                        | translatePat(formalsList[i], getType(formalsList[i]), formalVars[i], my_btscopes, it, muFailReturn(ftype), subjectAssigned=hasParameterName(formalsList, i) ) 
                        | i <- reverse(index(formalsList)));
                        
     funCode = functionBody(isVoidType(ftype.ret) || !addReturn ? params_when_body : muReturn1(ftype.ret, params_when_body), ftype, formalVars, isMemo);
     funCode = visit(funCode) { case muFail(fname) => muFailReturn(ftype) };
     
     funCode = removeDeadCode(funCode);
    
     alwaysReturns = ftype.returnsViaAllPath || isVoidType(getResult(ftype));
     formalsBTFree = isEmpty(formalsList) || all(f <- formalsList, backtrackFree(f));
     if(!formalsBTFree || (formalsBTFree && !alwaysReturns)){
        funCode = muBlock([muEnter(fname, funCode), muFailReturn(ftype)]);
     }
      
     funCode = removeDeadCode(funCode);

     return <formalVars, funCode>;
}

/********************************************************************/
/*                  Translate tags in a function declaration        */
/********************************************************************/

// Some library functions need special tratement when called from compiled code.
// Therefore we provide special treatment for selected Java classes. 
// A Java class X.java can be extended with a class XCompiled.java
// and all calls are then first routed to XCompiled.java that can selectively override methods.
// The compiler checks for the existence of a class XCompiled.java

private str resolveLibOverriding(str lib){
   getVariableInitializationsInModule();
   
	if(lib in getNotOverriddenlibs()) return lib;
	
	if(lib in getOverriddenlibs()) return "<lib>Compiled";

    rlib1 = replaceFirst(lib, "org.rascalmpl.library.", "");
    rlib2 = |std:///| + "<replaceAll(rlib1, ".", "/")>Compiled.class";
  
	if(exists(rlib2)){
	   addOverriddenLib(lib);
	   //println("resolveLibOverriding <lib> =\> <lib>Compiled");
	   return "<lib>Compiled";
	} else {
	     addNotOverriddenLib(lib);
		//println("resolveLibOverriding <lib> =\> <lib>");
		return lib;
	}
}

public map[str,str] translateTags(Tags tags){
   m = ();
   for(tg <- tags.tags){
     str name = "<tg.name>";
     if(name == "license")
       continue;
     if(tg is \default){
        cont = "<tg.contents>"[1 .. -1];
        m[name] = name == "javaClass" ? resolveLibOverriding(cont) : cont;
     } else if (tg is empty)
        m[name] = "";
     else
        m[name] = "<tg.expression>";
   }
   return m;
}

bool ignoreCompiler(map[str,str] tagsMap)
    = !isEmpty(domain(tagsMap) &  {"ignore", "Ignore", "ignoreCompiler", "IgnoreCompiler"});

//private bool ignoreCompilerTest(map[str, str] tags) = !isEmpty(domain(tags) & {"ignoreCompiler", "IgnoreCompiler"});

bool ignoreTest(map[str, str] tags) = !isEmpty(domain(tags) & {"ignore", "Ignore", "ignoreCompiler", "IgnoreCompiler"});

/********************************************************************/
/*       Translate the modifiers in a function declaration          */
/********************************************************************/

private list[str] translateModifiers(FunctionModifiers modifiers){
   lst = [];
   for(m <- modifiers.modifiers){
     if(m is \java) 
       lst += "java";
     else if(m is \test)
       lst += "test";
     else
       lst += "default";
   }
   return lst;
} 