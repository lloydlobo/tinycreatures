/*

# Warp fragment shader

## References

- [trinketMage - Base warp fBM](https://www.shadertoy.com/view/tdG3Rd)
- [Inigo Quilez - warp](https://iquilezles.org/articles/warp/)
- [Inigo Quilez - fbm](https://iquilezles.org/articles/fbm/)

*/

extern vec2 screen;//> `love.graphics.getDimensions()`
extern float time;//> `love.timer.getTime()`

const float TWO_PI = 6.28318;

struct Palette{
    vec3 dc_offset;
    vec3 amp;
    vec3 freq;
    vec3 phase;
};
const Palette PAL_BLUE_MAGENTA_ORANGE=Palette(
    vec3(.938,.328,.718),
    vec3(.659,.438,.328),
    vec3(.388,.388,.296),
    vec3(2.538,2.478,.16)
);
const Palette PAL_RED_BLUE=Palette(
    vec3(.5,.0,.5),
    vec3(.5,.0,.5),
    vec3(.5,.0,.5),
    vec3(.0,.0,.5)
);
const Palette PAL_GREY_BLUE=Palette(
    vec3(.5,.5,.5),
    vec3(.5,.5,.5),
    vec3(1.,1.,1.),
    vec3(.263,.416,.557)
);

uniform Palette pal=PAL_BLUE_MAGENTA_ORANGE;

/*
`cosine` based palette: `t` runs from 0 to 1 (normalized palette index or domain), the cosine
oscilates c times with a phase of d. The result is scaled and biased by a and b to meet the desired
contrast and brightness.

color(t) = a + b ⋅ cos[ 2π(c⋅t+d)]
color(t) = dc_offset + amp ⋅ cos[ 2π⋅(freq⋅t+phase) ]

See also:
• https://iquilezles.org/articles/palettes/
• http://dev.thi.ng/gradients/
*/
vec3 palette(float t)
{
    return pal.dc_offset+pal.amp*cos(TWO_PI*(pal.freq*t+pal.phase));
}

float rand(vec2 n)
{
    return fract(sin(dot(n,vec2(12.9898,4.1414)))*43758.5453);
}

float noise(vec2 p)
{
    vec2 ip=floor(p);
    vec2 u=fract(p);
    
    // Polynomial smoothstep
    u=u*u*(3.-2.*u);
    
    // Seems to feather each sector (with vec2)
    float res=mix(
        mix(rand(ip),rand(ip+vec2(1.,0.)),u.x),
        mix(rand(ip+vec2(0.,1.)),rand(ip+vec2(1.,1.)),u.x),u.y
    );
    
    return res*res;
}

const mat2 MTX=mat2(.8,.6,-.6,.8);

float fbm(vec2 p)
{
    float t=time*.0625; t*=4.;
    
    float f=0.;
    
    f+=.500000*noise(p+t); p=MTX*p*2.02;
    f+=.031250*noise(p);   p=MTX*p*2.01;
    f+=.250000*noise(p);   p=MTX*p*2.03;
    f+=.125000*noise(p);   p=MTX*p*2.01;
    f+=.062500*noise(p);   p=MTX*p*2.04;
    f+=.015625*noise(p+sin(t));
    
    return f/.968750;
}

float pattern(in vec2 p)
{
    return fbm(p+fbm(p));
}

vec4 effect(vec4 color,Image image,vec2 uvs,vec2 screen_coords)
{
    float f_aspect=screen.x/screen.y;
    vec2 uv=screen_coords/screen;
    vec2 uv0=uv;
    uv.x*=f_aspect;
    vec4 pixel=Texel(image,uvs);
    float f_shade=pattern(uv);
    vec3 col=palette(f_shade);
    return pixel*vec4(col*.5,1.);
}


/*

# Notes

## Floating point numbers

> "use always f subscript for the floating point constants,
> otherwise a double will be stored in the executable,
> and a innecesary conversion will occur"
> ─ [Inigo Quilez](https://iquilezeles.org/articles/compilingsmall/)

*/
