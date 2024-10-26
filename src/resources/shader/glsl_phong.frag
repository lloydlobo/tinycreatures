#define NUM_LIGHTS 32

struct Light{
        vec2 position;
        vec3 diffuse;
        float power;
};

extern Light lights[NUM_LIGHTS];
extern int num_lights;

extern vec2 screen;

const float constant=1.;
const float linear=.09;
const float quadratic=.032;

vec4 effect(vec4 color,Image image,vec2 uvs,vec2 screen_coords){
        vec4 pixel=Texel(image,uvs);

        vec2 norm_screen=screen_coords/screen;
        vec3 diffuse=vec3(0);

        for(int i=0;i<num_lights;i++){
                Light light=lights[i];
                vec2 norm_position=light.position/screen;

                float distance=length(norm_position-norm_screen)*light.power;
                float attenuation=1./(constant+linear*distance+quadratic*(distance*distance));
                diffuse+=light.diffuse*attenuation;
        }

        diffuse=clamp(diffuse,0.,1.);

        return pixel*vec4(diffuse,1.);
}
