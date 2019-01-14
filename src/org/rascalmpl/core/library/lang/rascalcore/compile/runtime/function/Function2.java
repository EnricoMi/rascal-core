package org.rascalmpl.core.library.lang.rascalcore.compile.runtime.function;

@FunctionalInterface
public interface Function2<R, A, B> {
	public R call(final A a, final B b);
}